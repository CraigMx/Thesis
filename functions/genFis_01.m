%% Function fis_01
% Author: Craig Maxwell
% Date: 13/06/2020
% Description: Create a separate FIS for each agent in the system. For
% simulation 01. 

%% To do
% Check which variables should be returned from this function

%% Script 
function [fisArray] = genFis_01(n_a)

  n_in            = 3;
  n_out           = 1;
  n_MF_in         = [3 3 3];
  n_MF_out        = [1];

  name_in         = ["time", "priority", "downWindProximity"];
  name_out        = ["attraction"];

  range_in        = [ 0 600; 
                      0 1; 
                      0 1];
  range_out       = [0 1];

  MF_shape_in     = ["trimf", "trimf", "trimf"];
  MF_shape_out    = ["linear"];
  MF_range_in(:,:,1) = [0   60  120; 
                        60  120 300; 
                        120 300 6000];
  MF_range_in(:,:,2) = [- 1/4 0/4 1/4; 
                          1/4 2/4 3/4; 
                          3/4 4/4 5/4];
  MF_range_in(:,:,3) = [0, 0, 0.25; 
                        0, 0.25, 0.5; 
                        0.25, 0.5, 1];
  MF_range_out    = [1 600 1 1];
  MF_name_in      = [ "short", "medium", "long";
                      "low", "medium", "high";
                      "low", "medium", "high"];
                    
  MF_name_out     = ["outputMF1"];

  ruleList        = [ 1 1 1 1 1 1;
                      1 1 2 1 1 1;
                      1 1 3 1 1 1;
                      1 2 1 1 1 1;
                      1 2 2 1 1 1;
                      1 2 3 1 1 1;
                      1 3 1 1 1 1;
                      1 3 2 1 1 1;
                      1 3 3 1 1 1;
                      2 1 1 1 1 1;
                      2 1 2 1 1 1;
                      2 1 3 1 1 1;
                      2 2 1 1 1 1;
                      2 2 2 1 1 1;
                      2 2 3 1 1 1;
                      2 3 1 1 1 1;
                      2 3 2 1 1 1;
                      2 3 3 1 1 1;
                      3 1 1 1 1 1;
                      3 1 2 1 1 1;
                      3 1 3 1 1 1;
                      3 2 1 1 1 1;
                      3 2 2 1 1 1;
                      3 2 3 1 1 1;
                      3 3 1 1 1 1;
                      3 3 2 1 1 1;
                      3 3 3 1 1 1];

  %% Generate FIS
  for a=1:n_a
      % Create new sugfis object
      fis = sugfis;

      %% Inputs
      for i_in = 1:n_in
        fis = addInput (fis, range_in(i_in, :),'Name', name_in(i_in));
        for i = 1:n_MF_in(i_in)
          fis = addMF(fis, name_in(i_in), MF_shape_in(i_in), MF_range_in(i, :, i_in), 'Name', MF_name_in(i_in, i));
        end
      end

      %% Outputs
      for i_out = 1:n_out
        fis = addOutput (fis, range_out(i_out, :),'Name', name_out(i_out));
        for i = 1:n_MF_out(i_out)
          fis = addMF(fis, name_out(i_out), MF_shape_out(i_out), MF_range_out(i, :, i_out), 'Name', MF_name_out(i_out, i));
        end
      end

      %% Rule base
      fis = addRule(fis, ruleList);

      %% Add to FIS array
      fisArray(a) = fis;
  end
end