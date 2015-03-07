## homebrew-launchd: programs patched to set environment in launchd

## Introduction

This collection of formula include patches to some common applications that
need to affect the environment of running GUI applications.

A great example of this is gpg-agent.  Out of the box, there is no way for
gpg-agent to push it's settings via launchctl so running GUI applications
can see it.  Sure, you can write a wrapper script and call that, but,
then you have to maintain your wrapper script, etc.
