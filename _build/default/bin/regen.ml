open Lib_generate.Regenerate
open Cmdliner

let () = Random.self_init ()

module W = Word.String

type segment_impl =
  | ThunkList
  | ThunkListMemo
  | LazyList
  | StrictSet
  | Trie

module type ARG = sig
  include Segments.OrderedMonoid
  include Segments.Trie.WORD with type t := t
end
module type S =
  functor (W : ARG) -> (Segments.S with type elt = W.t)

let get_impl_mod : segment_impl -> (module S) = let open Segments in function
  | ThunkList -> (module ThunkList)
  | ThunkListMemo -> (module ThunkListMemo)
  | LazyList -> (module LazyList)
  | StrictSet -> (module StrictSet)
  | Trie -> (module Trie.Make)

type conf =
  | All
  | Sample of { skip : int ; length : int option }
  | Take of int

let[@inline] make_impl ~impl =
  let module M = (val get_impl_mod impl) in
  let module S = M(W) in
  let module A = Make (W) (S) in
  fun[@inline] ~sigma ->
    let sigma = S.of_list @@ List.map W.singleton @@ CCString.to_list sigma in
    let module Sigma = struct type t = S.t let sigma = sigma end in
    let module A = A (Sigma) in
    fun conf re ->
      
      let lang = A.gen re in
      match conf with
      | All -> Printf.printf "All"; A.flatten lang
      | Sample { skip ; length } ->
        Printf.printf "Sample"; CCFun.(%) ignore @@ A.sample ~skip ?n:length lang
      | Take n -> Printf.printf "Take"; Iter.take n @@ A.flatten @@ A.compl lang

let make_impl_positive =
  let module M = (val get_impl_mod ThunkList) in
  let module S = M(W) in
  let module A = Make (W) (S) in
  fun ~sigma ->
    let sigma = S.of_list @@ List.map W.singleton @@ CCString.to_list sigma in
    let module Sigma = struct type t = S.t let sigma = sigma end in
    let module A = A (Sigma) in
    fun conf re ->
      let lang = A.gen re in
      match conf with
      | All -> A.flatten lang
      | Sample { skip ; length } ->
        CCFun.(%) ignore @@ A.sample ~skip ?n:length lang
      | Take n -> Iter.take n @@ A.flatten lang

let make_impl_negative =
  let module M = (val get_impl_mod ThunkList) in
  let module S = M(W) in
  let module A = Make (W) (S) in
  fun ~sigma ->
    let sigma = S.of_list @@ List.map W.singleton @@ CCString.to_list sigma in
    let module Sigma = struct type t = S.t let sigma = sigma end in
    let module A = A (Sigma) in
    fun conf re ->
      let lang = A.gen re in
      match conf with
      | All -> A.flatten @@ A.compl lang
      | Sample { skip ; length } ->
        CCFun.(%) ignore @@ A.sample ~skip ?n:length @@ A.compl lang
      | Take n -> Iter.take n @@ A.flatten @@ A.compl lang

let tl = make_impl ~impl:ThunkList ~sigma:"ab"
let tlm = make_impl ~impl:ThunkListMemo ~sigma:"ab"
let ll = make_impl ~impl:LazyList ~sigma:"ab"
let set = make_impl ~impl:StrictSet ~sigma:"ab"
let trie = make_impl ~impl:Trie ~sigma:"ab"

let get_impl ~impl ~sigma = Printf.printf "flag %b\n" (sigma <> "ab"); if sigma <> "ab" then
     make_impl ~impl ~sigma
  else match impl with
  | ThunkList -> tl
  | ThunkListMemo -> tlm
  | LazyList -> ll
  | StrictSet -> set
  | Trie -> trie

let get_implv2 ~sigma conf regex =
  let neg = make_impl_negative ~sigma conf regex in
  let pos = make_impl_positive ~sigma conf regex in
  (pos,neg)

let backend = 
  let doc = Arg.info ~docv:"IMPLEM" ~doc:"Implementation to use."
      ["i";"implementation"]
  in
  let c = Arg.enum [
      "ThunkList", ThunkList ;
      "ThunkListMemo", ThunkListMemo ;
      "LazyList", LazyList ;
      "StrictSet", StrictSet ;
      "Trie", Trie ;
    ]
  in
  Arg.(value & opt c ThunkList & doc)

let skip =
  let doc = Arg.info ~docv:"SAMPLE"
      ~doc:"Average sampling interval."
      ["s";"sample"]
  in
  Arg.(value & opt (some int) None & doc)

let sigma =
  let doc = Arg.info ~docv:"ALPHABET" ~doc:"Alphabet used by the regular expression"
      ["a";"alphabet"]
  in
  let default = CCString.of_list @@ CCOpt.get_exn @@ Regex.enumerate ' ' '~' in
  Arg.(value & opt string default & doc)

let setupv2 ~sigma re = 
  Fmt_tty.setup_std_outputs ();
  get_implv2 ~sigma re

let _print_allv2 sigma re length (skip:int option) =
  let conf = match length, skip with
    | Some n, None -> Take n
    | None, None -> All
    | _, Some skip -> Sample { skip ; length }
  in 
  setupv2 ~sigma conf re    