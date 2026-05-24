%% =====================================================================
%% PHALANX FLIGHT MECHANICS ENGINE: DYNAMIC METHOD A PHYSICS INITIALIZATION
%% =====================================================================
% Description: Parses the AIRLoad manifest, extracts layout specifications, 
% and solves the dynamic non-linear pitching moment equations of motion over 
% a 13.5-hour flight timeline to track true trim-drag fuel propagation.

clear; clc; close all;

%% 1. Parse AIRLoad Template JSON Configuration
jsonFilename = 'AIRLoad_SQ322_SINLHR_20260522_131537.json';

if ~exist(jsonFilename, 'file')
    error(['Error: The file "%s" is missing from your active folder. ' ...
           'Please drag and drop the file into your left-hand Files panel.'], jsonFilename);
end

fileID = fopen(jsonFilename, 'r', 'n', 'UTF-8');
rawText = fread(fileID, '*char')';
fclose(fileID);

data = jsondecode(rawText);

fprintf('================================================================\n');
fprintf('             PHALANX METHOD A FLIGHT MECHANICS ENGINE           \n');
fprintf('================================================================\n');
fprintf('Aircraft Type   : %s\n', data.aircraft);
fprintf('Mission Profile : %s (%s -> %s)\n', data.flight.flight_number, data.flight.origin, data.flight.destination);
fprintf('================================================================\n\n');

%% 2. Extract Mission Variables & Aircraft Geometries
flight_duration_hrs = data.flight.flight_hours;       % 13.5 hours
initial_fuel_mass   = data.weight_breakdown.fuel_kg;   % 108,000 kg

% Airbus A350-1000 Reference Geometries (Meters from nose datum)
X_LEMAC = 26.35;   % Leading Edge of Mean Aerodynamic Chord
C_MAC   = 7.07;    % Chord length
X_AC_w  = 28.15;   % Wing Aerodynamic Center (Center of Lift position)
X_tail  = 61.20;   % Horizontal Stabilizer Aerodynamic Center position

%% 3. Process Total Flight Mass Breakdown
OEW_mass  = data.weight_breakdown.operating_empty_weight_kg; % 155,000 kg
pax_mass  = data.weight_breakdown.passengers_kg;             % 26,600 kg
cargo_items  = data.cargo_manifest;
num_items    = length(cargo_items);
cargo_masses = zeros(num_items, 1);
cargo_arms   = zeros(num_items, 1);

for i = 1:num_items
    cargo_masses(i) = cargo_items(i).weight_kg; %
    cargo_arms(i)   = cargo_items(i).zone_x_m;  %
end
total_cargo_mass = sum(cargo_masses);

% Calculate Zero Fuel Weight (ZFW) - constant throughout flight
ZFW_mass = OEW_mass + pax_mass + total_cargo_mass;

%% 4. Establish Simulation Initial Configuration Center of Gravity Positions
% --- Configuration A: AI-Optimized Target ---
cg_mac_AI      = data.centre_of_gravity.ramp_cg_pct_mac; % 27.643 %MAC
cg_x_meters_AI = X_LEMAC + (cg_mac_AI / 100) * C_MAC;

% --- Configuration B: Unoptimized Fleet Average Baseline ---
cg_mac_Avg      = 26.50; % 26.5% MAC
cg_x_meters_Avg = X_LEMAC + (cg_mac_Avg / 100) * C_MAC;

%% 5. Execute Comparative Flight Mechanics Integration Engine
% This runs our dynamic Method A state-space physics solver
[time_vec, fuel_burn_Avg, fuel_burn_AI, cg_history_Avg, cg_history_AI, drag_Avg, drag_AI] = ...
    run_method_A_physics_engine(flight_duration_hrs, ZFW_mass, initial_fuel_mass, cg_x_meters_Avg, cg_x_meters_AI, X_LEMAC, C_MAC, X_AC_w, X_tail);

%% 6. Process Simulation Outputs & Metrics
total_burned_Avg = fuel_burn_Avg(end);
total_burned_AI  = fuel_burn_AI(end);
fuel_saved_kg    = total_burned_Avg - total_burned_AI;
percentage_saved = (fuel_saved_kg / total_burned_Avg) * 100;

fprintf('\n================ PHALANX DYNAMIC METHOD A REPORT ================\n');
fprintf('Initial Takeoff Weight  : %.1f kg\n', ZFW_mass + initial_fuel_mass);
fprintf('Baseline Pre-Flight CG  : %.3f %%MAC\n', cg_mac_Avg);
fprintf('AI-Optimized Pre-Flight : %.3f %%MAC\n', cg_mac_AI);
fprintf('----------------------------------------------------------------\n');
fprintf('Standard Profile Total Fuel Burned: %.2f kg\n', total_burned_Avg);
fprintf('AI-Optimized Profile Fuel Burned : %.2f kg\n', total_burned_AI);
fprintf('----------------------------------------------------------------\n');
fprintf('DYNAMIC TOTAL JET FUEL SAVED     : %.2f kg\n', fuel_saved_kg);
fprintf('NET MISSION FUEL EFFICIENCY RATIO: %.3f %%\n', percentage_saved);
fprintf('================================================================\n');

%% 7. Export Values to Simulink Workspace
assignin('base', 'phalanx_initial_mass', ZFW_mass + initial_fuel_mass);
assignin('base', 'phalanx_initial_cg_mac', cg_mac_AI);

%% 8. Telemetry Plotting
figure('Name', 'PHALANX Dynamic Performance Layout', 'Color', [1 1 1]);

% Subplot 1: Total Drag Comparison Curve
subplot(3,1,1);
plot(time_vec/3600, drag_Avg/1000, 'r--', 'LineWidth', 2); hold on;
plot(time_vec/3600, drag_AI/1000, 'b-', 'LineWidth', 2);
grid on; ylabel('Total Drag (kN)');
legend('Standard Layout', 'AI Optimized', 'Location', 'NorthEast');
title('Dynamic Trim Aerodynamic Airframe Drag Profiles');

% Subplot 2: Dynamic Center of Gravity Progression (Tracking Fuel Burnout)
subplot(3,1,2);
plot(time_vec/3600, cg_history_Avg, 'r--', 'LineWidth', 2); hold on;
plot(time_vec/3600, cg_history_AI, 'b-', 'LineWidth', 2);
grid on; ylabel('CG Location (%MAC)');
title('Longitudinal CG Migration Tracking Flight Fuel Burn-Out');

% Subplot 3: Cumulative Saved Fuel Mass Timeline
subplot(3,1,3);
fuel_divergence = fuel_burn_Avg - fuel_burn_AI;
area(time_vec/3600, fuel_divergence, 'FaceColor', [0.1 0.6 0.1], 'FaceAlpha', 0.4);
grid on; xlabel('Mission Duration (Hours)'); ylabel('Net Fuel Saved (kg)');
title('Cumulative Mission Fuel Savings via Trim Elimination');

%% =====================================================================
%% DYNAMIC METHOD A FLIGHT MECHANICS CALCULATOR ENGINE
%% =====================================================================
function [t, f_Avg, f_AI, cg_hist_Avg, cg_hist_AI, drag_hist_Avg, drag_hist_AI] = ...
    run_method_A_physics_engine(hours, ZFW, initial_fuel, initial_cg_Avg, initial_cg_AI, X_LEMAC, C_MAC, X_AC_w, X_tail)

    steps = 1000;
    t = linspace(0, hours * 3600, steps)';
    dt = t(2) - t(1);
    
    % Pre-allocate historical array trackers
    f_Avg = zeros(steps, 1); f_AI = zeros(steps, 1);
    cg_hist_Avg = zeros(steps, 1); cg_hist_AI = zeros(steps, 1);
    drag_hist_Avg = zeros(steps, 1); drag_hist_AI = zeros(steps, 1);
    
    % Initialize structural flight loops
    current_fuel_Avg = initial_fuel;
    current_fuel_AI  = initial_fuel;
    
    % Cruising Constant Parameters
    rho = 0.380;       % Denser air density scale at cruise altitude FL350 (kg/m^3)
    V = 243.0;         % Mach 0.85 typical cruise velocity (m/s)
    S_ref = 443.0;     % Standard A350-1000 main wing surface area reference (m^2)
    b_wing = 64.75;    % Main wing span width (meters)
    b_tail = 19.50;    % Tail plane span width (meters)
    C_D0 = 0.0145;     % Zero-lift parasitic profile drag coefficient reference
    e_wing = 0.85;     % Wing Oswald efficiency factor
    e_tail = 0.80;     % Tail plane Oswald efficiency factor
    
    % Specific Fuel Consumption (SFC) for Rolls-Royce Trent XWB (kg of fuel per Newton of thrust per second)
    SFC = 1.41e-5; 
    
    % Wing Pitching Moment reference parameter
    M_ac_wing = -115000 * 9.81; % Aerodynamic constant pitching moment (N*m)

    for k = 1:steps
        % --------------------------------------------------------------
        % RUN 1: STANDARD FLEET AVERAGE PROFILE STATE CALCULATIONS
        % --------------------------------------------------------------
        W_Avg = (ZFW + current_fuel_Avg) * 9.81; % Instantaneous total system weight (Newtons)
        
        % Dynamic tracking of CG migration as fuel burns out from the wing tank reference arm (27.5m)
        %
        moment_ZFW_Avg = ZFW * ((initial_cg_Avg - X_LEMAC)/C_MAC * 100); % Base moment vector
        current_cg_x_Avg = (ZFW*initial_cg_Avg + current_fuel_Avg*27.5) / (ZFW + current_fuel_Avg);
        cg_hist_Avg(k) = ((current_cg_x_Avg - X_LEMAC) / C_MAC) * 100;
        
        % Solve Trim Equation A: Tail Downforce required for pitch stability
        L_tail_Avg = (W_Avg * (current_cg_x_Avg - X_AC_w) + M_ac_wing) / (X_tail - X_AC_w);
        
        % Solve Trim Equation B: Main Wing Lift
        L_wing_Avg = W_Avg - L_tail_Avg;
        
        % Calculate Individual Dynamic Induced Drag Factors
        C_L_wing_Avg = L_wing_Avg / (0.5 * rho * V^2 * S_ref);
        C_D_wing_induced_Avg = (C_L_wing_Avg^2) / (pi * (b_wing^2 / S_ref) * e_wing);
        
        % Tail drag scale based on horizontal stabilizer surface profile
        C_L_tail_Avg = L_tail_Avg / (0.5 * rho * V^2 * (S_ref * 0.22)); 
        C_D_tail_induced_Avg = (C_L_tail_Avg^2) / (pi * (b_tail^2 / (S_ref * 0.22)) * e_tail) * 0.22;
        
        Total_CD_Avg = C_D0 + C_D_wing_induced_Avg + C_D_tail_induced_Avg;
        Thrust_Required_Avg = Total_CD_Avg * (0.5 * rho * V^2 * S_ref);
        drag_hist_Avg(k) = Thrust_Required_Avg;
        
        % --------------------------------------------------------------
        % RUN 2: AI-OPTIMIZED CARGO LAYOUT PROFILE STATE CALCULATIONS
        % --------------------------------------------------------------
        W_AI = (ZFW + current_fuel_AI) * 9.81;
        
        current_cg_x_AI = (ZFW*initial_cg_AI + current_fuel_AI*27.5) / (ZFW + current_fuel_AI);
        cg_hist_AI(k) = ((current_cg_x_AI - X_LEMAC) / C_MAC) * 100;
        
        % Solve Trim Equation A (AI Config)
        L_tail_AI = (W_AI * (current_cg_x_AI - X_AC_w) + M_ac_wing) / (X_tail - X_AC_w);
        
        % Solve Trim Equation B (AI Config)
        L_wing_AI = W_AI - L_tail_AI;
        
        % Calculate Individual Dynamic Induced Drag Factors (AI Config)
        C_L_wing_AI = L_wing_AI / (0.5 * rho * V^2 * S_ref);
        C_D_wing_induced_AI = (C_L_wing_AI^2) / (pi * (b_wing^2 / S_ref) * e_wing);
        
        C_L_tail_AI = L_tail_AI / (0.5 * rho * V^2 * (S_ref * 0.22));
        C_D_tail_induced_AI = (C_L_tail_AI^2) / (pi * (b_tail^2 / (S_ref * 0.22)) * e_tail) * 0.22;
        
        Total_CD_AI = C_D0 + C_D_wing_induced_AI + C_D_tail_induced_AI;
        Thrust_Required_AI = Total_CD_AI * (0.5 * rho * V^2 * S_ref);
        drag_hist_AI(k) = Thrust_Required_AI;
        
        % --------------------------------------------------------------
        % State Propagation Engine (Integration updates fuel reduction vectors)
        % --------------------------------------------------------------
        fuel_flow_Avg = Thrust_Required_Avg * SFC; % kg/sec
        fuel_flow_AI  = Thrust_Required_AI * SFC;  % kg/sec
        
        current_fuel_Avg = current_fuel_Avg - (fuel_flow_Avg * dt);
        current_fuel_AI  = current_fuel_AI - (fuel_flow_AI * dt);
        
        f_Avg(k) = initial_fuel - current_fuel_Avg;
        f_AI(k)  = initial_fuel - current_fuel_AI;
    end
end