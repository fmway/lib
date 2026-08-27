{
  # get the priority value, useful in the outside evalModules
  resolvePriority = values: 
    let
      normalize = v: 
        if v._type or "" == "override" then v else { priority = 100; content = v; };
      winner = builtins.foldl' (acc: rawCurr: 
        let curr = normalize rawCurr; in if curr.priority <= acc.priority then curr else acc
      ) { priority = 9999; content = null; } values;
    in winner.content;
}
