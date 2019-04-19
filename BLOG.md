Setup of Jython for RED, the Robot Framework editor for Eclipse

# Introduction

When you use RED, you can use Python with Robotframework and all its installed libraries (Selenium for instance) to launch tests. However, if you use Maven and thus the Maven Robotframework plugin, you risk to use a different Robotframework version with RED than you use with Maven. Plus, the Python variant in RED cannot use Java libraries like the Maven variant does (which is based on Jython). You may use Jython of course but the last versions 2.7.0 and 2.7.1 did not run well on my Windows 7 laptop due to Pip and DLL problems. And Jython seems to be not so well supported as Python.

But there seemed to be a solution: [http://nokia.github.io/RED/help/user\_guide/tools\_integration/maven.html](http://nokia.github.io/RED/help/user_guide/tools_integration/maven.html) that describes a way to use the same Robotframework jar as Maven does. In that solution the launch4j program is used to create a jython.exe based on the Robotframework Jar (which includes Jython as well). There are a few snags however as I discovered when I tried to use it.

# Problems encountered

## Classpath entries

First, you have to hard code your Jar libraries as Java classpath entries into the launch4j configuration file. That means that if you need a new Jar library you would need to recreate the Jython executable. And I needed not only Robotframework, Selenium but also a database library and a JMS library. And other projects may have other constraints. Actually what you would like to use is the compile classpath of Maven which has a complete list of jars and dependencies.

## Jython arguments

The second problem was that RED launches that generated Jython program with arguments not recognized by the robotframework.jar (for instance -J-cp &lt;classpath&gt;) or with arguments just applicable for a Java interpreter like -Dvar=value. And the robotframework.jar invoked by this generated jython.exe does not recognize these arguments.

## Java version

The third and last problem was that the launch4j search for the Java executable is a little bit too sophisticated: it uses the Windows registry to look for a system-wide installed JRE/JDK with a minimum and/or maximum version. On the Windows 7 system I was using, only Java 1.7 was installed system-wide and I had no privileges to install a higher version. And the Selenium library really needed Java 1.8.

# A workaround

So what to do?

The first and second problem are actually environment problems. I needed another program to setup an environment (for instance set environment variables, determine the Maven classpath and change the command line) before launching the robotframework.jar with arguments it recognizes. My old friend, script language Perl, came to my rescue. The Windows variant Strawberry Perl allows you to create executables based on Perl scripts using the Perl CPAN module Par::packer.

So the idea is to create an executable named jython.exe that is called from the Eclipse RED editor and that sets up the environment before launching java with the robotframework.jar.

All the build steps must be automated as well of course and what is more easy to use than good old Ant? I really have no idea,  🙂

# Installation

Before you start, you may need to install some programs, 🙂

And since my corporate development machine lacked admin rights that posed some problems, 🙁

## HTTP proxy

Before we can start to download without a browser, we may need to define an HTTP proxy.

Check if the Internet Explorer settings define a HTTP proxy URL. If so, open that URL in a browser, look for the proxy and set an environment variable https\_proxy, for instance http\_proxy=http://a.b.c.d:port.

## Strawberry Perl

Do not use an installer that needs admin rights.

I used the portable edition, see [http://strawberryperl.com/releases.html](http://strawberryperl.com/releases.html), and installed it in directory C:\Strawberry.

Define an environment variable PERL\_HOME to point to C:\Strawberry\perl. This is needed by Ant later on.

Also define a shortcut on your Desktop with C:\Strawberry\portableshell.bat as target. This helps to setup a portable Perl shell.

### Module PAR::Packer

Use the shortcut to start a portable Perl shell. For the rest of this document this will be displayed as

DOS&gt;

Download PAR::Packer from the CPAN archives:

DOS&gt; cpan PAR::Packer

It takes some time before it is ready with all the tests being executed.

But then you should be able to find pp like this:

DOS&gt; where pp

## Ant

Just download it from the Apache site or use one already on the system:

DOS&gt; dir/s/b c:\ant.bat

Add the Ant bin directory to environment variable PATH.

## Java

You need a Java 1.8 or higher to be installed somewhere and let the environment variable JAVA\_HOME point to that directory.

# Build

You will find these files in the source directory:

- build.xml, an Ant build file
- jython.pl, a Perl script to setup the environment for the robotframework jar

This will create and test the executable:

DOS&gt; pushd c:\jython

DOS&gt; ant build test

If there are no errors, you are ready to configure RED.

You can cleanup by:

DOS&gt; ant clean


# Configuration

Before we can run the Jython executable we need to define the Robot framework Java libraries.

## Robot framework Java libraries

The Perl executable (jython.exe) uses environment variable RF\_JAR and all environment variables named RF\_\*\_JAR to setup the environment variable CLASSPATH.

You need to run at least once an automated test with Maven in order to get all the libraries in the %USERPROFILE%\.m2\repository directory.

In my case I needed these Java libraries to set via environment variables to run the automated tests in RED:

RF\_JAR=C:\Users\T427377\.m2\repository\org\robotframework\robotframework\3.0.4\robotframework-3.0.4.jar

RF\_JMSLIBRARY\_JAR=C:\Users\T427377\git\ics-VCCUSTOM-422\icsIntegrationTest\src\test\resources\robotframework\libraries\robotframework-jmslibrary-1.0.0.jar

## RED

Follow the instructions on [https://github.com/nokia/RED](https://github.com/nokia/RED) to install RED in Eclipse if needed.

I added [http://master.dl.sourceforge.net/project/red-robot-editor/repository](http://master.dl.sourceforge.net/project/red-robot-editor/repository) to the install sites to manage.

Next install RED.

You may encounter a security warning about unsigned content. I accepted anyway.

At the end, just click &quot;Restart Now&quot;:

When everything is ready, you will have a Robot perspective.

Go to Window -&gt; Preferences -&gt; Robot Framework -&gt; Installed frameworks and let Eclipse discover all the frameworks (normally that starts automatically). Remove all frameworks but the one framework having as Path c:\jython\bin.

Apply and Close and you are ready!