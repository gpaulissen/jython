Installation of Jython for RED, the Robot Framework editor for Eclipse

# Introduction

This installation manual describes first how to create a Jython executable for RED
using the same Java libraries as when Maven is used with the Robot Framework
Maven plugin. Next, it describes how to configure it in Eclipse.

The target environment here is a Windows environment (it has been tested on
Windows 7 and Windows 10), but it might also work on a Unix like environment.

NOTE: every time you define an environment variable in the Configuration Panel
you will need to stop and restart the process which needs it, for instance the
command prompt (portable Perl shell) or Eclipse used later on.

# Installation

Before you start, you may need to install some programs and since my corporate
development machine lacked admin rights that posed some problems.

## HTTP proxy

Before you can start to download without a browser, you may need to define an
HTTP proxy.

Check if the Internet Explorer settings define a HTTP proxy URL. If so, open
that URL in a browser, look for the proxy and set an environment variable
https\_proxy, for instance http\_proxy=http://a.b.c.d:port.

## Strawberry Perl

Do not use an installer that needs admin rights.

I used the portable edition, see
[http://strawberryperl.com/releases.html](http://strawberryperl.com/releases.html),
and installed it in directory C:\Strawberry.

Define an environment variable PERL\_HOME to point to C:\Strawberry\perl. This
is needed by Ant later on.

Also define a shortcut on your Desktop with C:\Strawberry\portableshell.bat as
target. This helps to start a portable Perl shell.

### Module PAR::Packer

Use the shortcut to start a portable Perl shell. For the rest of this document
this will be displayed as:

DOS&gt;

Install PAR::Packer from the CPAN archives:

DOS&gt; cpan PAR::Packer

It takes some time before it is ready with all the tests being executed.

But then you should be able to find pp like this:

DOS&gt; where pp

## Ant

Just download it from the Apache site or use one already on the system:

DOS&gt; dir/s/b c:\ant.bat

Add the Ant bin directory to environment variable PATH: a simple way of doing
this is to define ANT\_HOME and add %ANT\_HOME%\bin to PATH.

## Maven

Just download it from the Apache site or use one already on the system:

DOS&gt; dir/s/b c:\mvn.cmd

Add the Maven bin directory to environment variable PATH: a simple way of
doing this is to define environment variable MAVEN\_HOME and add
%MAVEN\_HOME%\bin to PATH.

## Java

You need a Java 1.8 or higher to be installed somewhere and let the
environment variable JAVA\_HOME point to that directory.

# Build

You will find these files in the source directory:

- build.xml - an Ant build file
- jython.pl - a Perl script to set up the environment for the robotframework jar

This will create and test the executable:

DOS&gt; ant build test

If there are no errors, you are ready to configure RED.

You can cleanup by:

DOS&gt; ant clean


# Configuration

## Java class path

Before we can run the Jython executable we need to know where to find the
Robot Framework Java libraries.

This is done by letting the Java class path contain the Robot Framework Java
libraries, either by using Maven or environment variables.

### Maven

If a file named pom.xml exists in the Eclipse project folder, the Jython
executable will use Maven to determine its dependent libraries and thus to set
up the Java class path. This is done automatically by the Jython executable.

This is the preferred and most simple way to use the executable.

### Robot Framework Java libraries as environment variables

If there is no Maven pom.xml as described above, the Jython executable uses
environment variable RF\_JAR and all environment variables named RF\_\*\_JAR
to set up the Java class path. You need to define these variables.

You need to run at least once an automated test (a build) with Maven in order
to get all the libraries in the %USERPROFILE%\\.m2\repository directory.

This is an example:

RF\_JAR=%USERPROFILE%\\.m2\repository\org\robotframework\robotframework\3.0.4\robotframework-3.0.4.jar

The environment variables RF\_\*\_JAR are optional.

## Selenium webdrivers

In order to run Selenium you need their webdrivers (chromedriver.exe,
etcetera) either as Java system properties or to be found in the PATH.

The easiest way to set up Selenium webdrivers is to install [Katalon
Studio](https://www.katalon.com/) and then to set environment variable
KATALON_HOME pointing to the installation directory.

## RED

Follow the instructions on
[https://github.com/nokia/RED](https://github.com/nokia/RED) to install RED in
Eclipse if needed.

You may encounter a security warning about unsigned content, but I accepted anyway.

At the end, just click &quot;Restart Now&quot;:

When everything is ready, you will have a Robot perspective.

Go to Window -&gt; Preferences -&gt; Robot Framework -&gt; Installed
frameworks and let Eclipse discover all the frameworks (normally that starts
automatically). Remove all frameworks but the one framework having as Path
c:\jython\bin assuming you installed the sources into c:\jython.

Apply and Close and you are ready!


# Environment variables

This is a list of environment variables (possibly) used in this document:
* https\_proxy
* PERL\_HOME
* ANT\_HOME
* MAVEN\_HOME
* JAVA\_HOME
* RF\_JAR
* RF\_\*\_JAR
