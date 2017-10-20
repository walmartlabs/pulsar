# Release History

## 0.3.0 -- UNRELEASED

Changed the logic so that completed jobs *do not* bubble up.
Completed jobs are culled only when they are above all completed jobs.

## 0.2.0 -- 13 Oct 2017

Added `Pulsar.prefix/2`: set a prefix displayed immediately before the job message.

Added `Pulsar.pause/0` and `Pulsar.resume/0`: temporarily disable the
dashboard to allow for other console output.

## 0.1.0 -- 9 Oct 2017

Initial release.
