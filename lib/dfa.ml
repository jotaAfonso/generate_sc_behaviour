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