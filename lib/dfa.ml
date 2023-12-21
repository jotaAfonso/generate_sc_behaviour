(*
open Model.Contract
open Model.FiniteAutomaton
open Printf

let reg_exp = ""

let _printhashv2 x = 
  Hashtbl.iter (fun x y -> printf "%s - %s " x y) x

let _printhashv1 x = 
  Hashtbl.iter (fun x y -> printf "%s -> " x; _printhashv2 y; printf "\n") x

let populate_table t (l : string list) =
  List.iter (fun x -> Hashtbl.add t x "") l 

let rec list_states (l : string list) length states =
  match l with
    [] -> []
    | x :: xs -> let y = Hashtbl.create (List.length l) in populate_table y states; 
      [(x, y)] @ list_states xs length states

let start_has_incoming auto =
  List.exists (fun transition -> 
     String.equal transition.resultState auto.initial_state) auto.transitions

let end_has_outgoing auto =
  List.exists (fun e -> (List.exists (fun transition -> 
    String.equal transition.requiredState e) auto.transitions)) auto.end_states

let handle_start_incoming auto =
  if start_has_incoming auto then (
    let local_transitions = auto.transitions in
    let new_transition = { operationlabel = "$"; requiredState = "Qi"; resultState = auto.initial_state } in
    { initial_state = "Qi"; states = auto.states @ ["Qi"]; transitions = [new_transition] @ local_transitions; end_states = auto.end_states }
  ) else auto  

let rec treat_final_transitions end_states =
  match end_states with 
    [] -> []
    | x :: xs -> [{ operationlabel = "$"; requiredState = x; resultState = "Qf" }] @ treat_final_transitions xs

let handle_final_outgoing auto =
  if end_has_outgoing auto then (
    let local_transitions = auto.transitions in
    let new_transitions = treat_final_transitions auto.end_states in
    { initial_state = auto.initial_state; states = auto.states @ ["Qf"]; transitions = new_transitions @ local_transitions; end_states = ["Qf"] }
  ) else auto

let get_input_symbol auto =
  let input_symbols = Hashtbl.create @@ List.length auto.states  in
  List.iter (fun state -> Hashtbl.add input_symbols state (Hashtbl.create @@ List.length auto.states)) auto.states;
  List.iter (fun t ->
      let transition = Hashtbl.find input_symbols t.requiredState in
      match Hashtbl.find_opt transition t.resultState with
      | Some existing_transition -> Hashtbl.replace transition t.resultState (existing_transition ^ "+" ^t.operationlabel)
      | None -> Hashtbl.replace transition t.resultState t.operationlabel)
    auto.transitions;
  input_symbols

let get_pred_succ (auto : automaton) state input_symbols =
  printf "State %s\n" state;
  let predecessors = ref [] in
  let successors = ref [] in
  let curr_dict_for_from : (string, string) Hashtbl.t = Hashtbl.create @@ Hashtbl.length input_symbols in  
  Hashtbl.iter (fun st val' ->
      match Hashtbl.find_opt val' state with
        None -> ()
        | x -> Hashtbl.add curr_dict_for_from st (Option.get x)
  ) input_symbols; 
  
  List.iter (fun predecessor ->
      if predecessor <> state then (
        match Hashtbl.find_opt curr_dict_for_from predecessor with
        | Some pred_state_transition when pred_state_transition <> "" -> predecessors := predecessor :: !predecessors
        | _ -> ()
      ))
      auto.states;
  List.iter (fun successor ->
      if successor <> state then (
        match Hashtbl.find_opt (Hashtbl.find input_symbols state) successor with
        | Some succ_state_transition when succ_state_transition <> "" -> successors := successor :: !successors
        | _ -> ()
      ))
    auto.states;
  (!predecessors, !successors)

let check_self_loop state input_symbols =
  match Hashtbl.find_opt (Hashtbl.find input_symbols state) state with
  | Some self_loop_transition when self_loop_transition <> "" -> true
  | _ -> false

let dfa_to_regex auto input_symbols state_initial state_final =
  List.iter (fun state ->
    printf "cs %s \n" state;
    let (predecessors, successors) = get_pred_succ auto state input_symbols in
    if not (state = state_initial || state = state_final) then (
      List.iter (fun predecessor ->
        printf "cp %s \n" predecessor;
        if Hashtbl.mem input_symbols predecessor then
          List.iter (fun successor ->
            printf "cu %s \n" successor;
            if Hashtbl.mem (Hashtbl.find input_symbols predecessor) successor then

              printf "Entrei \n" ;
              let pre_suc_input_exp =
                match Hashtbl.find_opt (Hashtbl.find input_symbols predecessor) successor with
                  | Some transition when transition <> "" -> "(" ^ transition ^ ")"
                  | _ -> ""
                in
              let self_loop_input_exp =
                if check_self_loop state input_symbols then
                  "(" ^ (Hashtbl.find (Hashtbl.find input_symbols state) state) ^ ")" ^ "*"
                else
                  ""
              in
              let from_pre_input_exp =
                match Hashtbl.find_opt (Hashtbl.find input_symbols predecessor) state with
                  | Some transition when transition <> "" -> "(" ^ transition ^ ")"
                  | _ -> ""
                in
              let to_suc_input_exp =
                match Hashtbl.find_opt (Hashtbl.find input_symbols state) successor with
                  | Some transition when transition <> "" -> "(" ^ transition ^ ")"
                  | _ -> ""
                in
              let new_pre_suc_input_exp =
                from_pre_input_exp ^ self_loop_input_exp ^ to_suc_input_exp
              in
              let pre_suc_input_exp =
                if pre_suc_input_exp <> "" then
                  new_pre_suc_input_exp ^ "+" ^ pre_suc_input_exp
                else
                  new_pre_suc_input_exp
              in
              Hashtbl.replace (Hashtbl.find input_symbols predecessor) successor pre_suc_input_exp
            ) successors
          )
        ) predecessors;
        if not (state = state_initial || state = state_final) then
          Hashtbl.remove input_symbols state
      )
    auto.states;
    Hashtbl.find (Hashtbl.find input_symbols state_initial) state_final
    
let get_regex (automaton : automaton) =
  let auto_start = handle_start_incoming automaton in
  let auto = handle_final_outgoing auto_start in
  let input_symbol = get_input_symbol auto in 
  dfa_to_regex auto input_symbol auto.initial_state (List.hd auto.end_states)
  *)

(* Since the algorithm only works for deterministic automaton, we first convert it
					to its deterministic equivalent *)

open Model.FiniteAutomaton



module RegExpSyntax = struct
    (*  Grammar:
        E -> E + E | E E | E* | c | (E) | ()

      Grammar with priorities:
        E -> T | T + E
        T -> F | F T
        F -> A | A*
        A -> P | c
        P -> (E) | ()
    *)
  type t =
    | Plus of t * t
    | Seq of t * t
    | Star of t
    | Symb of string
    | Empty
    | Zero
  ;;

let rec toStringN n re =
  match re with
    | Plus(l, r) ->
        (if n > 0 then "(" else "") ^
        toStringN 0 l ^ "+" ^ toStringN 0 r
        ^ (if n > 0 then ")" else "")
    | Seq(l, r) ->
        (if n > 1 then "(" else "") ^
        toStringN 1 l ^ toStringN 1 r
        ^ (if n > 1 then ")" else "")
    | Star(r) ->
        toStringN 2 r ^ "*"
    | Symb(c) -> c
    | Empty -> "~"
    | Zero -> "!"

let toString re =
  toStringN 0 re
end  

let transitionGet1 trns = List.sort_uniq compare (List.map ( fun (a,_,_) -> a ) trns)
let transitionGet2 trns = List.sort_uniq compare (List.map ( fun (_,b,_) -> b ) trns)
let transitionGet3 trns = List.sort_uniq compare (List.map ( fun (_,_,c) -> c ) trns)
let transitionGet23 trns = List.sort_uniq compare (List.map (fun(_,b,c) -> (b,c)) trns) 
        

let nextStates st sy t =			
  let n = List.filter (fun (a,b,_c) -> st = a && sy = b) t in
    transitionGet3 n     

let nextEpsilon1 st ts =
  let trns = List.filter (fun (a,b,_c) -> st = a && b = "~") ts in
  let nextStates = transitionGet3 trns in	
List.sort_uniq compare (st :: nextStates) 


let rec closeEmpty sts t = 
  let ns = List.sort_uniq compare (List.flatten (List.map (fun st -> nextEpsilon1 st t) sts)) in
    if (List.for_all (fun x -> List.mem x ns) sts) then ns else closeEmpty (List.sort_uniq compare (sts @ ns)) t 
  
let fuseStates sts = String.concat "_" sts 

let toDeterministic  (auto : automaton) =
  let move sts sy ts = List.sort_uniq compare (List.flatten (List.map (fun st -> nextStates st sy ts ) sts)) in	
				
  (* generates the set of states reachable from the given state set though the given symbol *)
  let newR oneR sy ts = 
    let nxtSts = move oneR sy ts in
    let clsempty = closeEmpty nxtSts ts in
    List.sort_uniq compare (nxtSts @ clsempty) in
    
  (* creates all transitions (given state set, a given symbol, states reachable from set through given symbol) *)
  let rToTs r = 
    let nxtTrans = List.sort_uniq compare ( List.map (fun sy -> (r, sy, newR r sy auto.transitions)) auto.alphabet) in
      List.filter (fun (_,_,z) -> not (z = [])) nxtTrans in
    
  (* applies previous function to all state sets until no new set is generated *)
  let rec rsToTs stsD rD trnsD alph = 
    let nxtTs = List.sort_uniq compare (List.flatten (List.map (fun stSet -> rToTs stSet ) rD)) in
    let nxtRs = List.sort_uniq compare ( List.map (fun (_,_,z) -> z) nxtTs) in
    let newRs = List.filter (fun r -> not (List.mem r stsD)) nxtRs in
    if newRs = [] then (List.sort_uniq compare (trnsD @ nxtTs)) else 
      rsToTs (List.sort_uniq compare (newRs @ stsD)) newRs (List.sort_uniq compare (trnsD @ nxtTs)) alph  in	
  
  
  let r1 = closeEmpty (List.sort_uniq compare [auto.initialState]) auto.transitions in
  
  (* all transitions of the new deterministic automaton *)				
  let trnsD = rsToTs (List.sort_uniq compare [r1]) (List.sort_uniq compare [r1]) [] auto.alphabet in
          
  let tds = List.sort_uniq compare ( List.map (fun (a,b,c) -> (fuseStates ( a), b, fuseStates ( c))) trnsD) in
      
  let newInitialState = fuseStates (r1) in
  
  let stSet1 = List.sort_uniq compare ( List.map (fun (a,_,_) -> a) trnsD) in
  let stSet2 = List.sort_uniq compare ( List.map (fun (_,_,c) -> c) trnsD) in
  let stSet = List.sort_uniq compare (stSet1 @ stSet2) in
  
  let isAccepState st = List.mem st auto.acceptStates in
  let hasAnAccepSt set = List.exists (fun st -> isAccepState st ) set in
  let newAccStsSet = List.filter (fun set -> hasAnAccepSt set) stSet in
  
  let newAllSts = List.sort_uniq compare ( List.map (fun set -> fuseStates ( set)) stSet) in
  let newAccSts = List.sort_uniq compare ( List.map (fun set -> fuseStates ( set)) newAccStsSet) in
  
  { alphabet = auto.alphabet; allStates = newAllSts; initialState = newInitialState; transitions = tds; acceptStates = newAccSts }

          
let regularExpression auto = 
  let det = toDeterministic auto in
    
  let sts = det.allStates in
  let trns = det.transitions in
  
  (* transforms the set of expressions into the regex: plus of all expressions of the set *)			
  let plusSet reSet =
    let rec pls l =
      match l with
        [] -> RegExpSyntax.Zero
        | x::xs -> if xs = [] then x else RegExpSyntax.Plus (x, pls xs)
    in
      pls ( reSet)
  in
  
  (* For the given i and j, returns the value of R when k is zero.
    Note that k will always be 0 when called inside this method *)
  let calczerok k i j = 
    let ts = List.filter (fun (a,_,b) -> i = a && j = b) trns in
    if ts <> [] then
      if i <> j then 
        let res = List.sort_uniq compare ( List.map (fun (_,c,_) -> RegExpSyntax.Symb c) ts) in 
          (k,i,j,plusSet res)								
      else 
        let res = List.sort_uniq compare ( List.map (fun (_,c,_) -> RegExpSyntax.Symb c) ts) in 
        let re = RegExpSyntax.Plus(RegExpSyntax.Empty, (plusSet res)) in
          (k,i,j,re)
          
    else (k,i,j,RegExpSyntax.Zero)
  in
  
  
  (* For the given i and j, returns the value of R when k is not zero. *)
  let calck k i j prvK = 
    let getRij i j = 
      let r = List.nth (List.filter (fun (_,x,y,_) -> x = i && y = j) prvK) 0 in
        (fun (_,_,_,re) -> re) r
    in
    let assembleRe st i j =
      let rik = getRij i st in
      let rkk = RegExpSyntax.Star (getRij st st) in
      let rkj = getRij st j in						
        RegExpSyntax.Seq(rik, RegExpSyntax.Seq(rkk,rkj)) 
    in
    
    let rij = getRij i j in
    let rikjs = List.sort_uniq compare ( List.map (fun st -> assembleRe st i j) sts) in
    let rikj = plusSet rikjs in
      (k,i,j,RegExpSyntax.Plus(rij,rikj)) 
      
  in					
    
  (* Main function that applies previous 2 functions to all possible i and j pairs *)	
  let rec rkij k = 
    if k < 1 then
      List.sort_uniq compare ( List.map (fun (i,j) -> calczerok k i j) (List.sort_uniq compare (List.flatten (List.map (fun x -> List.map (fun y -> (x,y)) sts) sts))))
    else 
      let prvK = rkij (k-1) in
        List.sort_uniq compare ( List.map (fun(i,j) -> calck k i j prvK) (List.sort_uniq compare (List.flatten (List.map (fun x -> List.map (fun y -> (x,y)) sts) sts))))
  in
  
  let allRks = rkij (List.length sts) in 
  let result = List.filter (fun (_,i,j,_) -> i = det.initialState && List.mem j det.acceptStates ) allRks in
  let res = List.sort_uniq compare ( List.map (fun (_,_,_,re) -> re) result) in
  let newRe = plusSet res in
  
    RegExpSyntax.toString newRe
