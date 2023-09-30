open Lib_generate.Regenerate
open Lib_generate.Regex

let () = Printexc.record_backtrace true

(* Turn a regular expression from Regenerate into an Re one. *)
let rec to_re = function x->
  match x with
    | One -> Re.epsilon
    | Set (true, l) -> Re.set @@ CCString.of_list l
    | Set (false, l) -> Re.compl [Re.set @@ CCString.of_list l]
    | Seq (re, re') -> Re.seq [to_re re; to_re re']
    | Or (re, re') -> Re.alt [to_re re; to_re re']
    | And (re, re') -> Re.inter [to_re re; to_re re']
    | Not _re -> assert false (* Re does not handle arbitrary complement. *)
    | Rep (i,j,re) -> Re.repn (to_re re) i j

(* Check positive and negative samples. *)
let check ((re : char t), pos, neg) =
  (* 1. Compile the regular expression. *)
  let cre =
    try
      Re.compile @@ Re.whole_string @@ to_re re
    with _ ->
      (* Discard regular expressions that Re does not handle. *)
      QCheck.assume_fail ()
  in
  (* 2. Test! *)
  List.for_all (fun s -> Re.execp cre s) pos &&
  List.for_all (fun s -> not @@ Re.execp cre s) neg

let test =
  let alphabet = ['1'; '2'; '3'] in
  let module Word = Word.String in
  let module Stream = Segments.ThunkList(Word) in
  let _re2 = Result.get_ok (parse "(Q2Q1)!(Q2)!") in
  let generator =
    arbitrary
      (module Word) (* Datastructure for words *)
      (module Stream) (* Datastructure for streams of words *)
      ~pp:Fmt.char (* Printer for characters *)
      ~compl: false
      ~samples:10 (* Average number of sampes for each regular expression *)
      alphabet (* Alphabet *)
      
  in
  QCheck.Test.make generator check

let () = QCheck_runner.run_tests_main [test]