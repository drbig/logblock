# logblock

**This is not a proper README. All here is very much WIP.**

The idea:

A [buruteblock](http://samm.kiev.ua/bruteblock/) 'clone' in pure Ruby that's actually general, non-assuming and portable.

What you can do with it:

You write a 'config file' utilising a pure Ruby DSL where you can watch a number of files; for each file you specify some Regexp expressions and timed-counter details (i.e. 'X matches in Y seconds') - for each Regexps you get keyed counters, and for each such counter-trigger you can write an action (including a helper for delayed 'clean-up' actions). You then run the config file/daemon and it takes care of the internal mechanics.

Simplest possible use-case (ala bruteblock for sshd):

    Logblock::Daemon.new do
      watch '/var/log/auth.log' do
        # block invalid username if 3 tries within 300s from an IP
        match /(Illegal|Invalid) user .*? from (?<key>.*)/, 3, 300 do |k, m|
          `ipfw table 1 add #{k}`
          after(7200) { `ipfw table 1 del #{k}` }
        end
      end
    end.run!

