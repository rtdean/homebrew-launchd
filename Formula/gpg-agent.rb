class GpgAgent < Formula
  homepage "https://www.gnupg.org/"
  url "ftp://ftp.gnupg.org/gcrypt/gnupg/gnupg-2.0.26.tar.bz2"
  mirror "ftp://ftp.mirrorservice.org/sites/ftp.gnupg.org/gcrypt/gnupg/gnupg-2.0.26.tar.bz2"
  sha1 "3ff5b38152c919724fd09cf2f17df704272ba192"

  depends_on "libgpg-error"
  depends_on "libgcrypt"
  depends_on "libksba"
  depends_on "libassuan"
  depends_on "pth"
  depends_on "pinentry"
  
  # Adjust package name to fit our scheme of packaging both
  # gnupg 1.x and 2.x, and gpg-agent separately
  patch :DATA

  def install
    # don't use Clang's internal stdint.h
    ENV["gl_cv_absolute_stdint_h"] = "#{MacOS.sdk_path}/usr/include/stdint.h"

    system "./configure", "--disable-dependency-tracking",
                          "--prefix=#{prefix}",
                          "--enable-agent-only",
                          "--with-pinentry-pgm=#{Formula["pinentry"].opt_bin}/pinentry",
                          "--with-scdaemon-pgm=#{Formula["gnupg2"].opt_libexec}/scdaemon"
    system "make", "install"
  end

  def caveats; <<-EOS.undent
      To replace ssh-agent with gpg-agent, you need to:
         * ensure that "enable-ssh-support" is in ~/.gnupg/gpg-agent.conf
         * ensure that "pinentry" in ~/.gnupg/gpg-agent.conf has a graphical PIN entry
           such as pinentry-mac (needed for GUI programs)
         * disable the system ssh-agent with
             launchctl unload -w /System/Library/LaunchAgents/org.openssh.ssh-agent.plist
         * have launchd start gpg-agent at login
    EOS
  end

  test do
    system "#{bin}/gpg-agent", "--help"
  end

  def plist; <<-EOS.undent
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>ProgramArguments</key>
        <array>
            <string>#{opt_prefix}/bin/gpg-agent</string>
            <string>-l</string>
            <string>--daemon</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>StandardErrorPath</key>
        <string>/dev/null</string>
        <key>StandardOutPath</key>
        <string>/dev/null</string>
        <key>ServiceDescription</key>
        <string>Run gpg-agent at login</string>
    </dict>
    </plist>
    EOS
  end
end

__END__
diff --git a/agent/gpg-agent.c b/agent/gpg-agent.c
index bf2a26d..7fe2586 100644
--- a/agent/gpg-agent.c
+++ b/agent/gpg-agent.c
@@ -67,6 +67,7 @@ enum cmd_and_opt_values
   oQuiet	  = 'q',
   oSh		  = 's',
   oVerbose	  = 'v',
+  oLaunchdSupport = 'l',

   oNoVerbose = 500,
   aGPGConfList,
@@ -200,6 +201,7 @@ static ARGPARSE_OPTS opts[] = {
   },
   { oWriteEnvFile, "write-env-file", 2|8,
             N_("|FILE|write environment settings also to FILE")},
+  { oLaunchdSupport, "launchd", 0, N_("launchd/launchctl support")},
   {0}
 };

@@ -604,6 +606,7 @@ main (int argc, char **argv )
   gpg_error_t err;
   const char *env_file_name = NULL;
   struct assuan_malloc_hooks malloc_hooks;
+  int launchd_support = 0;

   /* Before we do anything else we save the list of currently open
      file descriptors and the signal mask.  This info is required to
@@ -855,6 +858,10 @@ main (int argc, char **argv )
             env_file_name = make_filename ("~/.gpg-agent-info", NULL);
           break;

+        case oLaunchdSupport:
+          launchd_support = 1;
+          break;
+
         default : pargs.err = configfp? 1:2; break;
 	}
     }
@@ -1221,6 +1228,61 @@ main (int argc, char **argv )
             }
           else
             {
+              /* Use launchctl to update launchd environmental variables.
+                 This allows GUI programs/spotlight launched programs to
+                 access them */
+              if (launchd_support)
+              {
+                pid_t launchctl_pid;
+                char launchctl[] = "/bin/launchctl";
+                if ((launchctl_pid = fork()) == 0)
+                {
+                  char * p_infostr_var = strsep(&infostr, "=");
+                  char * const launchctl_argv[] = { launchctl, "setenv", p_infostr_var, infostr, NULL };
+                  if (execv(launchctl, launchctl_argv) < 0) {
+                    log_error("failed to set launchd environment: %s\n", strerror(errno));
+                    kill(pid, SIGTERM);
+                    exit(1);
+                  }
+                } else if (launchctl_pid < 0) {
+                  log_error("failed to set launchd environment: %s\n", strerror(errno));
+                  kill(pid, SIGTERM);
+                  exit(1);
+                }
+                if (opt.ssh_support)
+                {
+                  if ((launchctl_pid = fork()) == 0)
+                  {
+                    char * p_infostr_ssh_sock_var = strsep(&infostr_ssh_sock, "=");
+                    char * const launchctl_argv[] = { launchctl, "setenv", p_infostr_ssh_sock_var, infostr_ssh_sock,
+                                                      NULL };
+                    if (execv(launchctl, launchctl_argv) < 0) {
+                      log_error("failed to set launchd environment: %s\n", strerror(errno));
+                      kill(pid, SIGTERM);
+                      exit(1);
+                    }
+                  } else if (launchctl_pid < 0) {
+                    log_error("failed to set launchd environment: %s\n", strerror(errno));
+                    kill(pid, SIGTERM);
+                    exit(1);
+                  }
+                  if ((launchctl_pid = fork()) == 0)
+                  {
+                    char * p_infostr_ssh_pid_var = strsep(&infostr_ssh_pid, "=");
+                    char * const launchctl_argv[] = { launchctl, "setenv", p_infostr_ssh_pid_var, infostr_ssh_pid,
+                                                      NULL };
+                    if (execv(launchctl, launchctl_argv) < 0) {
+                      log_error("failed to set launchd environment: %s\n", strerror(errno));
+                      kill(pid, SIGTERM);
+                      exit(1);
+                    }
+                  } else if (launchctl_pid < 0) {
+                    log_error("failed to set launchd environment: %s\n", strerror(errno));
+                    kill(pid, SIGTERM);
+                    exit(1);
+                  }
+                }
+              }
               /* Print the environment string, so that the caller can use
                  shell's eval to set it */
               if (csh_style)
diff --git a/configure b/configure
index c022805..29d1742 100755
--- a/configure
+++ b/configure
@@ -578,10 +578,10 @@ MFLAGS=
 MAKEFLAGS=

 # Identity of this package.
-PACKAGE_NAME='gnupg'
-PACKAGE_TARNAME='gnupg'
+PACKAGE_NAME='gpg-agent'
+PACKAGE_TARNAME='gpg-agent'
 PACKAGE_VERSION='2.0.26'
-PACKAGE_STRING='gnupg 2.0.26'
+PACKAGE_STRING='gpg-agent 2.0.26'
 PACKAGE_BUGREPORT='http://bugs.gnupg.org'
 PACKAGE_URL=''
