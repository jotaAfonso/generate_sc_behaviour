(* Auto-generated from "types.atd" *)
[@@@ocaml.warning "-27-32-33-35-39"]

type transition_proj = { fromS: string; toS: string; action: string }

type association = { role: string; parts: string list }

type transition_global = {
  fromS: string;
  toS: string;
  action: string;
  new_p: association list;
  exi_p: association;
  input: string;
  preC: string;
  postC: string;
  internal: bool;
  extCall: bool
}

type proj = {
  id: string;
  role: string;
  parts: string list;
  initialS: string;
  states: string list;
  endS: string list;
  transitions: transition_proj list
}

type global = {
  id: string;
  initialS: string;
  states: string list;
  endS: string list;
  transitions: transition_global list;
  roles: string list;
  role_part: association list
}
