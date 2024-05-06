#!/usr/bin/env nu --no-std-lib --no-config-file

def "complete check" [message]: record -> string {
  let inp = $in
  if $inp.exit_code != 0 {
    print $message
    print ($inp | table)
    exit 1
  }
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

# Should return the status / output
def "test default" [file] {
  let f = $file | path expand --strict
  let d = mktemp --directory
  do {
    audible decrypt $"--dir=($d)" $f
  } | complete | inspect | complete check $"Failure while default decrypting file: ($f)"

  let default_chapters = $f | decoded_file_path $d | chapter_count
  
  do {
    audible decrypt $"--dir=($d)" "--overwrite" $f
  } | complete | complete check $"Failure while default decrypting overwrite: ($f)"

  let overwritten_chapters = $f | decoded_file_path $d | chapter_count

  rm -r $d

  if $default_chapters != $overwritten_chapters {
    print "X test default"
    exit 1
  }
  print "Y test default"
}

def "test rebuild-chapters" [file --force] {
  let f = $file | path expand --strict
  let d = mktemp --directory
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
  } | complete | inspect | complete check $"Failure while rebuilding chapter of ($f)"

  let num_chapters = $f | decoded_file_path $d | chapter_count

  do {
    audible ...$opts "--separate-intro-outro" "--overwrite" $f
  } | complete | inspect | complete check $"Failure while rebuilding chapter with separate intro/outro of ($f)"

  let num_chapters_with_separate_intro_outro = $f | decoded_file_path $d | chapter_count

  if ($num_chapters + 2) != $num_chapters_with_separate_intro_outro {
    print $"X test rebuild-chapters [separate intro/outro | force=($force)]"
    exit 1
  }

  do {
    audible ...$opts "--remove-intro-outro" "--overwrite" $f
  } | complete | inspect | complete check $"Failure while rebuilding chapter and removing intro/outro of ($f)"

  let num_chapters_without_separate_intro_outro = $f | decoded_file_path $d | chapter_count
  # FUTURE: Check if without intro/outro is shorter !
  if $num_chapters != $num_chapters_without_separate_intro_outro  {
    print $"X test rebuild-chapters [remove intro/outro | force=($force)]"
    exit 1
  }
  print $"Y test rebuild-chapters force=($force)"

  rm -r $d
}

# Calls `audible` internally.
# To test out different ffmpeg version, the result path should be added to the
# PATH
def main [] {
  # create temporary directory
  let correct_file = "./secrets/correct_file.aaxc"
  let requires_force_file = "./secrets/requires_force_file.aaxc"
  
  test default $correct_file
  test default $requires_force_file

  test rebuild-chapters $correct_file
  test rebuild-chapters --force $requires_force_file
}


