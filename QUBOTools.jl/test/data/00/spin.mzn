% id : 0
% description : Model 0 ~ Empty model
% 

set of int: Domain = {-1,1};
float: offset = 0.0;
float: scale = 1.0;

var float: objective = 0;

solve minimize objective;

output [show(scale*(objective + offset)), " - ", show(objective)];