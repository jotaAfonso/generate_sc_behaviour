open Model.Contract

let reg_exp = ""

let populate_table t (l : string list) =
  List.iter (fun x -> Hashtbl.add t x "") l 

let rec list_states (l : string list) length states =
  match l with
    [] -> []
    | x :: xs -> let y = Hashtbl.create (List.length l) in populate_table y states; [(x, y)] @ list_states xs length states

let get_input_symbol states transitions =
  let _print_hash x _ = Printf.printf "%s \n" x in  
  let input_symbols = (list_states states (List.length states) states) in  
  List.iter
    (fun transition ->
        let from_state = transition.requiredState in
        let _symbol = transition.operationlabel in
        let _to_state = transition.resultState in
        let state_map = List.assoc from_state input_symbols in
        if Hashtbl.find state_map _to_state = "" then Hashtbl.replace state_map _to_state _symbol
        else Hashtbl.replace state_map _to_state (Hashtbl.find state_map _to_state ^ "+" ^ _symbol))
        transitions;

  let _printhash x = Hashtbl.iter (fun x y -> Printf.printf "%s -> %s\n" x y) x in
  List.iter (fun (_, y) -> _printhash y) input_symbols;
  input_symbols
 
let get_pred_succ state input_symbols =
  let predecessors, successors = ref [], ref [] in
  let curr_dict_for_from =
    List.map (fun (st, val_dict) ->
        st, List.filter (fun (to_st, _) -> to_st = state) val_dict
      ) input_symbols in
  List.iter (fun (predecessor, val_dict) ->
      if not (List.mem_assoc predecessor curr_dict_for_from) || predecessor = state then
        ()
      else if !(List.assoc predecessor curr_dict_for_from) <> [] then
        predecessors := predecessor :: !predecessors
    ) dfa;

  List.iter (fun (successor, _) ->
      if not (List.mem_assoc state input_symbols) || state = successor then
        ()
      else if List.mem_assoc successor (List.assoc state input_symbols) &&
              !(List.assoc successor (List.assoc state input_symbols)) <> "" then
        successors := successor :: !successors
    ) dfa;
  !predecessors, !successors
  
  (*
let get_pred_succ state input_symbols =
  let predecessors =
    Hashtbl.fold
      (fun st val_map acc -> if st <> state && Hashtbl.find val_map state <> "" then st :: acc else acc)
      input_symbols
      []
  in
  let successors =
    List.filter (fun st -> st <> state && Hashtbl.mem (Hashtbl.find input_symbols state) st) (Hashtbl.find dfa "states" |> Yojson.Basic.Util.to_list |> List.map Yojson.Basic.Util.to_string)
  in
  (predecessors, successors)

let check_self_loop input_symbols state =
  Hashtbl.find (Hashtbl.find input_symbols state) state <> ""

let dfa_to_regex input_symbols state_initial state_final =
  let states = Hashtbl.find dfa "states" |> Yojson.Basic.Util.to_list |> List.map Yojson.Basic.Util.to_string in
  List.iter
    (fun state ->
        if state <> state_initial && state <> state_final then
          let predecessors, successors = get_pred_succ state input_symbols in
          List.iter
            (fun predecessor ->
              if Hashtbl.mem input_symbols predecessor then
                List.iter
                  (fun successor ->
                      if Hashtbl.mem (Hashtbl.find input_symbols predecessor) successor then
                        let pre_suc_input_exp =
                          if Hashtbl.find (Hashtbl.find input_symbols predecessor) successor <> "" then
                            "(" ^ Hashtbl.find (Hashtbl.find input_symbols predecessor) successor ^ ")"
                          else ""
                        in
                        let self_loop_input_exp =
                          if check_self_loop input_symbols state then
                            "(" ^ Hashtbl.find (Hashtbl.find input_symbols state) state ^ ")*"
                          else ""
                        in
                        let from_pre_input_exp =
                          if Hashtbl.find (Hashtbl.find input_symbols predecessor) state <> "" then
                            "(" ^ Hashtbl.find (Hashtbl.find input_symbols predecessor) state ^ ")"
                          else ""
                        in
                        let to_suc_input_exp =
                          if Hashtbl.find (Hashtbl.find input_symbols state) successor <> "" then
                            "(" ^ Hashtbl.find (Hashtbl.find input_symbols state) successor ^ ")"
                          else ""
                        in
                        let new_pre_suc_input_exp =
                          from_pre_input_exp ^ self_loop_input_exp ^ to_suc_input_exp
                        in
                        let pre_suc_input_exp =
                          if pre_suc_input_exp <> "" then
                            if new_pre_suc_input_exp <> "" then
                              new_pre_suc_input_exp ^ "+" ^ pre_suc_input_exp
                            else
                              pre_suc_input_exp
                          else
                            new_pre_suc_input_exp
                        in
                        Hashtbl.replace (Hashtbl.find input_symbols predecessor) successor pre_suc_input_exp)
                  successors)
            predecessors;
          Hashtbl.replace input_symbols state (Hashtbl.fold (fun _ v acc -> if v <> "" then v :: acc else acc) (Hashtbl.find input_symbols state) [] |> String.concat "+");
          Hashtbl.remove input_symbols state)
    states;
  Hashtbl.find (Hashtbl.find input_symbols state_initial) state_final

let start_has_incoming () =
  let initial_state = List.hd (Hashtbl.find dfa "start_states" |> Yojson.Basic.Util.to_list |> List.map Yojson.Basic.Util.to_string) in
  let transition_function = Hashtbl.find dfa "transition_function" |> Yojson.Basic.Util.to_list in
  List.exists (fun transition -> Yojson.Basic.Util.index transition 2 |> Yojson.Basic.Util.to_string = initial_state) transition_function

let end_has_outgoing () =
  let final_states = Hashtbl.find dfa "final_states" |> Yojson.Basic.Util.to_list in
  if List.length final_states > 1 then true
  else
    let final_state = List.hd final_states |> Yojson.Basic.Util.to_string in
    let transition_function = Hashtbl.find dfa "transition_function" |> Yojson.Basic.Util.to_list in
    List.exists (fun transition -> Yojson.Basic.Util.index transition 0 |> Yojson.Basic.Util.to_string = final_state) transition_function

let handle_start_incoming () =
  if start_has_incoming () then (
    Hashtbl.replace dfa "states" (Yojson.Basic.Util.to_string (Hashtbl.find dfa "states") ^ ",\"Qi\"");
    let transition_function = Hashtbl.find dfa "transition_function" |> Yojson.Basic.Util.to_list in
    let new_transition = `List [`String "Qi"; `String "$"; List.hd (Hashtbl.find dfa "start_states" |> Yojson.Basic.Util.to_list)] in
    Hashtbl.replace dfa "transition_function" (`List (new_transition :: transition_function));
    Hashtbl.replace dfa "start_states" (`List [`String "Qi"]))

let handle_final_outgoing () =
  if end_has_outgoing () then (
    Hashtbl.replace dfa "states" (Yojson.Basic.Util.to_string (Hashtbl.find dfa "states") ^ ",\"Qf\"");
    let final_states = Hashtbl.find dfa "final_states" |> Yojson.Basic.Util.to_list in
    let transition_function = Hashtbl.find dfa "transition_function" |> Yojson.Basic.Util.to_list in
    let new_transitions = List.map (fun final_state -> `List [`String (final_state |> Yojson.Basic.Util.to_string); `String "$"; `String "Qf"]) final_states in
    *)