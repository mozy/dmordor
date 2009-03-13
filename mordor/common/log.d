module mordor.common.log;

public import tango.util.log.Log;
import tango.text.Regex;
import tango.io.Stdout;

import mordor.common.config;
import mordor.common.stringutils;

alias mordor.common.stringutils.string string;

private ConfigVar!(string) _logfatal, _logerror, _logwarn, _loginfo, _logtrace;

static this()
{
	_logfatal = Config.lookup!(string)("log.fatalmask", ".*", "Regex of loggers to enable fatal for.");
	_logerror = Config.lookup!(string)("log.errormask", ".*", "Regex of loggers to enable error for.");
	_logwarn = Config.lookup!(string)("log.warnmask", ".*", "Regex of loggers to enable warning for.");
	_loginfo = Config.lookup!(string)("log.infomask", "", "Regex of loggers to enable info for.");
	_logtrace = Config.lookup!(string)("log.tracemask", "", "Regex of loggers to enable trace for.");
    _logfatal.monitor(&enableLoggers);
    _logerror.monitor(&enableLoggers);
    _logwarn.monitor(&enableLoggers);
    _loginfo.monitor(&enableLoggers);
    _logtrace.monitor(&enableLoggers);
}

public void enableLoggers()
{
    auto fatal = new Regex("^" ~ _logfatal.val ~ "$");
    auto error = new Regex("^" ~ _logerror.val ~ "$");
    auto warn = new Regex("^" ~ _logwarn.val ~ "$");
    auto info = new Regex("^" ~ _loginfo.val ~ "$");
    auto trace = new Regex("^" ~ _logtrace.val ~ "$");
    
    foreach(logger; Log.hierarchy) {
        Level level = Level.None;
        string name = logger.name;
        if (fatal.test(name)) {
            level = Level.Fatal;
        }
        if (error.test(name)) {
            level = Level.Error;
        }
        if (warn.test(name)) {
            level = Level.Warn;
        }
        if (info.test(name)) {
            level = Level.Info;
        }
        if (trace.test(name)) {
            level = Level.Trace;
        }
        if (logger.level != level) {
            logger.level = level;
        }
    }
}
