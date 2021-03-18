#  NSURLSession Instrumentation

## Usage 

Initialize this instrumentation after `TracerSdkProvider`, if using a custom provider.

` autoInstrumenter = URLSessionAutoInstrumentation(dateProvider: SystemDateProvider())
URLSessionAutoInstrumentation.instance = autoInstrumenter
autoInstrumenter?.enable()`


