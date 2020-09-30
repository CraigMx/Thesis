%% Main simulation script
% Author: Craig Maxwell
% Faculty: Control and Simulation, Aerospace Enigneering, Delft University of
% Technology

% TO DO: 
% combine initialise fis and initialise path planning?
% move MPC into one function

%% Define simulation set
% Define function handles
h_init_sim_1 = @()initialise_simulation();
h_init_env_1 = @()initialise_environment();
h_init_agt_1 = @(m_bo)initialise_agent();
h_init_pp_1 = @()initialise_pathPlanning();
h_init_MPC_1 = @()initialise_MPC();
h_plotting = @()initialise_plotting();

% Allocate appropriate function handles to appropriate simulation
simulation_set = {
  "SS01-1", h_init_sim_1, h_init_env_1, h_init_agt_1, h_init_pp_1, h_init_MPC_1;
  };
%   "SS01-2", h_init_sim_1, h_init_env_1, h_init_agt_1, h_init_pp_1, hand_init_MPC_2;
%   "SS01-3", h_init_sim_1, h_init_env_1, h_init_agt_1, h_init_pp_1, hand_init_MPC_3;
%   "SS01-4", h_init_sim_1, h_init_env_1, h_init_agt_1, h_init_pp_1, hand_init_MPC_4;

for sim = 1:size(simulation_set,1)
  %% Initialise simulation data
  [flag_mpc, solver, t_opt, ...
  test_fis_sensitivity, test_obj_sensitivity, test_solvers, fis_data, ...
  flag_data_exp, flag_fig_exp, exp_folder, exp_dir, ...
  t, t_f, dt_s, dk_a, dk_c, dk_e, dk_mpc, dk_prog, dt_a, dt_c, dt_e, dt_mpc, ...
  k, k_a, k_c, k_e, k_mpc, k_prog, endCondition, flag_finish, ...
  obj, s_obj, r_bo, r_fo] = simulation_set{sim,2}();
  %% Initialise models
  % Environment
  [l_x_e, l_y_e, ...
    m_bo, m_s, m_f_i, m_bt, ...
    c_fs_1, c_fs_2, v_w, ang_w] = simulation_set{sim,3}();
  % Agent
  [n_x_s, n_y_s, l_x_s, l_y_s, n_a, n_q, v_as, a_t_trav, ...
  t_scan_m, t_scan_c, a_task, a_loc, a_target, a_t_scan, ...
  m_scan, m_t_scan] = simulation_set{sim,4}(m_bo);
  % Path planning
  [c_prior_building, c_prior_open, m_prior, fisArray] = simulation_set{sim,5}();
  % MPC
  [n_p, fis_params, ini_params, A, b, Aeq, beq, lb, ub, nonlcon, ...
  nvars, h_MPC, fminsearchOptions, gaOptions, patOptions, parOptions] = simulation_set{sim,6}();

  %% Plotting variables
  % Axes may not be entirely accurate as coarsening may remove some
  % rows/columns from original map.
  % Axes for dynamic environment states
  ax_lat_env = linspace(m_p_ref.LatitudeLimits(1),  m_p_ref.LatitudeLimits(2),  n_x_e);
  ax_lon_env = linspace(m_p_ref.LongitudeLimits(1), m_p_ref.LongitudeLimits(2), n_y_e);
  % Axes for search map
  ax_lat_scan = linspace(m_p_ref.LatitudeLimits(1),  m_p_ref.LatitudeLimits(2),  n_x_s);
  ax_lon_scan = linspace(m_p_ref.LongitudeLimits(1), m_p_ref.LongitudeLimits(2), n_y_s);
  % History plots
  obj_hist    = [];
  s_obj_hist  = [];
  t_hist      = [];
  m_f_hist    = m_f_i;
  m_f_hist_animate = m_f_i;
  m_bt_hist   = m_bt;
  a_loc_hist    = [];
  for a = 1:n_a
    a_loc_hist(a,:) = [a_loc(a, 1), a_loc(a, 2), a, t];
  end
  m_scan_hist = zeros(1,2);
  m_dw_hist   = zeros(n_x_s, n_y_s);        % Downwind map history
  fis_param_hist = fis_params;

  %% Simulation variables
  % Time estimation
  % Number of desired data points
  n_prog_data = 100;
  % Avg travel time
  k_trav_avg = (t_scan_c + l_x_s/v_as)/dt_s;
  % Estimated sim time
  k_sim_est = k_trav_avg * n_x_s * n_y_s / n_a;
  % Save data time
  dk_v = k_sim_est / n_prog_data;
  ct_v = 0;

  %% Test setup

  % Objective function sensitivity test setup
  if test_obj_sensitivity
    p1_i = fis_params(1);
    p2_i = fis_params(2);
    p3_i = fis_params(3);
    p4_i = fis_params(4);
    obj_hist_eval   = [];
    obj_hist_sens   = [];
    ct_mpc_eval     = 0;
    ct_mpc_sens     = 0; 
    ct_mpc_sens_fin = 2;

    % Text Variables
    % Check these rangeps work properly
    n_sens_1  = 3;
    n_sens_2  = 3;
    n_sens_3  = 3;
    n_sens_4  = 3;
    r_sens    = 1;
    p1        = p1_i*linspace(1-r_sens, 1+r_sens, n_sens_1);
    p2        = p2_i*linspace(1-r_sens, 1+r_sens, n_sens_2);
    p3        = p3_i*linspace(1-r_sens, 1+r_sens, n_sens_3);
    p4        = p4_i*linspace(1-r_sens, 1+r_sens, n_sens_4);
  end

  %% Error checking
  if (v_w >= v_as)
    fprintf("ERROR: UAV airspeed lower than wind speed")
    return
  elseif (dk_a >= t_scan_c)
    fprintf("ERROR: UAV airspeed lower than wind speed")
    return
  end

  % Initialise plotting
  [] = h_plotting();
  
  %% Simulation
  while finishFlag == false
    % Start timer
    t_sim = tic;
    %% MPC
    if mpc_active
      if k_mpc*dk_mpc <= t
        % For reproducibility
        rng default;
        % Optimisation
        if solver == "fminsearch"
          [mpc_params, fval] = fminsearch(h_MPC, ini_params, fminsearchOptions);
        elseif solver == "ga"
          [mpc_params,fval] = ga(fun, nvars, A, b, Aeq, beq, lb, ub, nonlcon, gaOptions);   
        elseif solver == "patternsearch"
          [mpc_params,fval] = patternsearch(fun, ini_params, A, b, Aeq, beq, lb, ub, nonlcon, patOptions);   
        elseif solver == "particleswarm"
          [mpc_params,fval] = particleswarm(fun, nvars, lb, ub, parOptions);   
        end
        % Update FIS Parameters
        for a=1:n_a
          range       = 1 + (a - 1) * 4;
          fis_params  = mpc_params(range:range+3);
          fisArray(a).Outputs.MembershipFunctions.Parameters = fis_params;
        end
        % Update initial guess
        ini_params = mpc_params;
        % Record new parameters
        fis_param_hist = [fis_param_hist; mpc_params(1:n_a*4)];
        % Counter 
        k_mpc = k_mpc + 1;
      end
    end

    %% Path planning
    if k_c*dk_c <= k
      % Counter
      k_c = k_c + 1;
      % Path planner
      a_target = model_pathPlanning(...
        n_a, a_target, n_q, ...
        n_x_s, n_y_s, l_x_s, l_y_s, ...
        m_scan, m_t_scan, m_dw, m_prior, ...
        fisArray, ...
        a_t_trav, a_t_scan, ...
        ang_w, v_as, v_w, test_fis_sensitivity); 
    end

    %% Agent actions
    if k_a*dk_a <= k
      % Counter 
      k_a = k_a + 1;
      % Agent model
      [ m_scan, m_scan_hist, a_loc, a_loc_hist, a_task, a_target, ...
        a_t_trav, a_t_scan] ...
          = model_agent( n_a, ...
          m_t_scan, m_scan, m_scan_hist, ...
          a_loc, a_loc_hist, a_task, a_target, ...
          a_t_trav, a_t_scan, ...
          l_x_s, l_y_s, v_as, v_w, ang_w, dt_a, t, false);
    end

    %% Environment model
    if k_e*dk_e <= k
      % Counter 
      k_e = k_e + 1;
      % Environment map
      [m_f, m_f_hist, m_f_hist_animate, m_bt, m_dw] = model_environment(...
        m_f, m_f_hist, m_f_hist_animate, m_s, m_bo, m_bt, dt_e, k, n_x_e, n_y_e, ...
        v_w, ang_w, c_fs_1, c_fs_2, c_f_s, false);
    end

    %% Store variables
    if ct_v*dk_v <= k
      ct_v = ct_v + 1;
      t_hist(ct_v) = ct_v*dk_v*dt_s;
      s_obj_hist(ct_v)    = s_obj;
      obj_hist(ct_v)      = obj;
    end

    %% Objective function evaluation
    [s_obj, obj]  = calc_obj(m_f, m_bo, m_scan, r_bo, r_fo, dt_s, s_obj, n_x_e, n_y_e, n_x_s, n_y_s, c_f_s);
    %% Advance timestep
    t = t + dt_s;
    k = k + 1;

    %% Progress report
    if k_prog * dk_prog <= t
      report_progress(endCondition, t, t_f, m_scan, n_x_s, n_y_s);
      k_prog = k_prog + 1;
    end

    %% Check end condition
    [finishFlag] = flag_endCondition(endCondition, t, t_f, m_scan, n_x_s, n_y_s);
  end

  % Simulation time  
  t_end = toc(t_sim);

  %% Postprocessing

  % Generate folder name
  dateTime = datestr(now,"yyyy-mm-dd-HH-MM");
  folder = strcat(dateTime, "-", exp_folder);

  if flag_fig_exp
    % Generate and export figures 
    plotData  = {  
      "m_dw_hist",        m_dw_hist,        true;    
      "m_f_hist",         m_f_hist,         true;
      "m_scan_hist",      m_scan_hist,      true;
      "UAV_loc_hist",     a_loc_hist,       true;
      "s_obj_hist",       s_obj_hist,       true;
      "obj_hist",         obj_hist,         true;
      "m_bo",             m_bo,             true;
      "fis",              fisArray,         true;
      "m_prior",          m_prior,          true};

    if test_obj_sensitivity
      plotData = [plotData; {"obj_hist_sens", obj_hist_sens, true}];  
    end

    if mpc_active
      plotData = [plotData; {"fis_param_hist", fis_param_hist, true}]; 
    end

    plot_simulationData( plotData, exp_dir, folder, ...
              ax_lon_env, ax_lat_env, ax_lon_scan, ax_lat_scan, ...
              dk_v, t, n_x_s, n_y_s, n_a, ct_v, fisArray);
  end

  % Export data
  if flag_data_exp
    % Save working directory path
    work_dir = pwd;
    % Change to save directory
    cd(exp_dir); 
    % Save workspace  
    mkdir(folder);
    cd(folder);
    save(folder);
    % Go back to working directory
    cd(work_dir);
  end

end