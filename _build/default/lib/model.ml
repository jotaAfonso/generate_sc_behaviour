type operation = {
  operationlabel : string;
  requiredState  : string;
  resultState    : string;
}

type parameter = {
  parameterLabel : string;
  typeLabel      : string;
}

type contract = {
  templateLabel  : string;
  parameters     : parameter list;
  initialState   : string;
} 