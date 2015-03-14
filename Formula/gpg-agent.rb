class GpgAgent < Formula
  homepage "https://www.gnupg.org/"
  url "ftp://ftp.gnupg.org/gcrypt/gnupg/gnupg-2.0.27.tar.bz2"
  mirror "ftp://ftp.mirrorservice.org/sites/ftp.gnupg.org/gcrypt/gnupg/gnupg-2.0.27.tar.bz2"
  sha1 "d065be185f5bac8ea07b210ab7756e79b83b63d4"

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
             launchctl unload -w /System/Library/LaunchAgents/org.openbsd.ssh-agent.plist
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
            <string>/bin/sh</string>
            <string>-c</string>
            <string>#{opt_prefix}/bin/gpg-agent -c --daemon | /bin/launchctl</string>
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
diff --git a/configure b/configure
index c022805..96ea7ed 100755
--- a/configure
+++ b/configure
@@ -578,8 +578,8 @@ MFLAGS=
 MAKEFLAGS=

 # Identity of this package.
-PACKAGE_NAME='gnupg'
-PACKAGE_TARNAME='gnupg'
+PACKAGE_NAME='gpg-agent'
+PACKAGE_TARNAME='gpg-agent'
 PACKAGE_VERSION='2.0.27'
 PACKAGE_STRING='gnupg 2.0.27'
 PACKAGE_BUGREPORT='http://bugs.gnupg.org'
diff --git a/agent/gpg-agent.c b/agent/gpg-agent.c
index bf2a26d..a306d2f 100644
--- a/agent/gpg-agent.c
+++ b/agent/gpg-agent.c
@@ -1226,13 +1226,13 @@ main (int argc, char **argv )
               if (csh_style)
                 {
                   *strchr (infostr, '=') = ' ';
-                  printf ("setenv %s;\n", infostr);
+                  printf ("setenv %s\n", infostr);
 		  if (opt.ssh_support)
 		    {
 		      *strchr (infostr_ssh_sock, '=') = ' ';
-		      printf ("setenv %s;\n", infostr_ssh_sock);
+		      printf ("setenv %s\n", infostr_ssh_sock);
 		      *strchr (infostr_ssh_pid, '=') = ' ';
-		      printf ("setenv %s;\n", infostr_ssh_pid);
+		      printf ("setenv %s\n", infostr_ssh_pid);
 		    }
                 }
               else
