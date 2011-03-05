# DESCRIPTION

Export activity log, query log and warnings

## FEATURES/PROBLEMS

* Export to logfile.
* Rotate logfile.
* Show logfile using browser.

## INSTRATION

* Upload plugin files.
* Update permission. (e.g. chmod 777 /path/to/mt/plugins/LogExporter/log)

## USAGE

* Execute "tail -f /path/to/mt/plugins/LogExporter/log/mt.log"
* Open "http://example.com/mt/mt.cgi?\_\_mode=log\_exporter\_viewer" (Should have permission to read http://example.com/mt/plugins/LogExporter/log/mt.log)

## SETTINGS
	cat logger.yaml
	---
	loggers:
	    file:
	        class: file
	        filename: mt.log
	        #1MB
	        size: 1048576
	        max: 6
	
	types:
	    info:
	        logger: file
	        ansi_color:
	            - green
	            - on_black
	    warning:
	        logger: file
	        ansi_color:
	            - yellow
	            - on_black
	    error:
	        logger: file
	        ansi_color:
	            - red
	            - on_black
	    security:
	        logger: file
	        ansi_color:
	            - magenta
	            - on_black
	    debug:
	        logger: file
	        ansi_color:
	            - bright_green
	            - on_black
	    query:
	        logger: file
	        ansi_color:
	            - blue
	            - on_black
	    trace:
	        logger: file
	        ansi_color:
	            - bright_magenta
	            - on_black
	
## LICENSE

Copyright (c) 2011 ToI Inc.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
