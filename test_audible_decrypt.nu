#!/usr/bin/env nu --no-config-file

use std assert
use std log

# the testing framework of nushell is broken way too often
# and some core-contributors don't even recommend it.
# The better solution is to simply roll your own simple testing code
# or to move to Nupm.

# Run all available tests and stop at first error
export def main [] {
  let exec_path = which audible | get path | path expand
  log info $"Using the following audible path: ($exec_path)"  
  # Note: I cannot call ffmpeg -version as FFMPEG is a runtime path for the python
  # application and this would call the ffmpeg version of the local path!
  log info ("audible --version: " + (^audible --version))

  test_decrypt_default_no_force
  test_decrypt_default_force
  test_decrypt_rebuild_chapters_no_force 
  test_decrypt_rebuild_chapters_force 
}

def with-test-env [closure: closure]: nothing -> nothing {
  let requires_no_force_file = $"($env.PWD)/secrets/requires_no_force_file.aaxc"
  let msg_1 = $"Make sure to locally provide sample data that requires no force flag to rebuild the chapters under: ($requires_no_force_file)"
  assert ($requires_no_force_file | path exists) $msg_1

  let requires_force_file = $"($env.PWD)/secrets/requires_force_file.aaxc"
  let msg_2 = $"Make sure to locally provide sample data that requires the force flag to rebuild the chapters under: ($requires_force_file)"
  assert ($requires_force_file | path exists) $msg_2

  let temp = mktemp -d

  with-env {
    TEMP_DIR: $temp
    REQUIRES_NO_FORCE_FILE: $requires_no_force_file
    REQUIRES_FORCE_FILE: $requires_force_file
  } $closure
  
  rm --recursive $temp
}

export def test_decrypt_default_no_force [] {
  with-test-env {
    _test_decrypt_default $env.REQUIRES_NO_FORCE_FILE $env.TEMP_DIR
  }
}

export def test_decrypt_default_force [] {
  with-test-env {
    _test_decrypt_default $env.REQUIRES_FORCE_FILE $env.TEMP_DIR
  }
}

export def test_decrypt_rebuild_chapters_no_force [] {
  with-test-env {
    _test_decrypt_rebuild_chapters $env.REQUIRES_NO_FORCE_FILE $env.TEMP_DIR
  }
}

export def test_decrypt_rebuild_chapters_force [] {
  with-test-env {
    _test_decrypt_rebuild_chapters $env.REQUIRES_FORCE_FILE $env.TEMP_DIR --force
  }
}
  
def "complete check" [message]: record -> string {
  let inp = $in
  let msg = $"($message)\n\n($inp | table)"
  if $inp.exit_code != 0 {
   log error $msg 
   exit 1
  }

  log debug $inp.stdout
  $inp.stdout
}

def "decoded_file_path" [dir: path] {
  let new_base = $in | path parse | get stem | $"($in).m4b"
  return ($dir | path join $new_base | path expand --strict)
}

def "chapter_count" [] {
  let f = $in | path expand --strict
  ^ffprobe -v quiet -print_format json -show_chapters $f
  | complete
  | complete check $"Couldn't derive number of chapters for ($f)"
  | from json
  | get chapters
  | length
}

# Decrypt the given input file without any additional commands
# Tests overwriting by running the command twice and ensuring that
# the number of chapters remains identical
# FUTURE: Consider checking out smarter inspect commands
def _test_decrypt_default [
  file: path
  dir: path
] {
  log info "Testing decryption with default settings"
  let f = $file | path expand --strict
  do {
    audible decrypt $"--dir=($dir)" $f
  } | complete | complete check $"Failure while default decrypting file: ($f)"

  let default_chapters = $f | decoded_file_path $dir | chapter_count
  
  log info "Testing decryption with default settings and overwriting previous file"
  do {
    audible decrypt $"--dir=($dir)" "--overwrite" $f
  } | complete | complete check $"Failure while default decrypting overwrite: ($f)"

  let overwritten_chapters = $f | decoded_file_path $dir | chapter_count

  assert equal $default_chapters $overwritten_chapters "Decrypted files have different number of chapters!"
}

# Decrypt the given aaxc `file` and rebuild the chapters.
# Force rebuilding if `--force` is set.
# The data is decrypted three times:
# Once only with `--rebuild-chapters`
# Then with again with `--separate-intro-outro`
# And again with `remove-intro-outro`
# Will check if number of chapters is correct for the given configurations
def _test_decrypt_rebuild_chapters [
  file
  tmp_dir
  --force
] {
  log info "Testing decryption with chapter rebuilding"
  let d = $tmp_dir
  let f = $file | path expand --strict
  let force_opt = if $force {
    ["--force-rebuild-chapters"]
  } else {
    []
  }
  let opts = [
    "decrypt"
    $"--dir=($d)"
    "--rebuild-chapters"
  ] ++ $force_opt

  do {
    ^audible ...$opts $f
  } | complete | complete check $"Failure while rebuilding chapter of ($f)"

  let num_chapters = $f | decoded_file_path $d | chapter_count

  log info "Testing decryption with chapter rebuilding & separate intro/outro"
  do {
    audible ...$opts "--separate-intro-outro" "--overwrite" $f
  } | complete | complete check $"Failure while rebuilding chapter with separate intro/outro of ($f)"

  let num_chapters_with_separate_intro_outro = $f | decoded_file_path $d | chapter_count

  assert equal ($num_chapters + 2) $num_chapters_with_separate_intro_outro $"Failed [separate intro/outro | force=($force)]"

  log info "Testing decryption with chapter rebuilding & without intro/outro"
  do {
    audible ...$opts "--remove-intro-outro" "--overwrite" $f
  } | complete | complete check $"Failure while rebuilding chapter and removing intro/outro of ($f)"

  let num_chapters_without_separate_intro_outro = $f | decoded_file_path $d | chapter_count
  # FUTURE: Check if without intro/outro is shorter !

  assert equal $num_chapters $num_chapters_without_separate_intro_outro $"Failed [remove intro/outro | force=($force)]"
}

