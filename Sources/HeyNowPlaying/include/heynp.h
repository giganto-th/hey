#ifndef HEYNP_H
#define HEYNP_H

/// Prints one JSON line describing what macOS says is playing, then returns.
/// The signature matches a Perl XS function so the library can be loaded by /usr/bin/perl, which
/// (being an Apple-signed program) is allowed to read the system's Now Playing information.
void heynp_dump(void *interpreter, void *cv);

#endif
