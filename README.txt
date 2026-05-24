# AIRLoad for Airbus

AIRLoad is an aircraft cargo loading verification and decision-support prototype designed for Airbus wide-body operations mainly the A350 -1000. It helps improve aircraft loading accuracy by comparing the planned cargo load with the actual loading state, calculating aircraft centre of gravity (CG), and flagging unsafe or inefficient loading conditions.

The prototype demonstrates how  digital twin logic, AI-assisted loading recommendations can be integrated into one aircraft loading workflow.

---

## Project Overview

AIRLoad addresses a real operational challenge in aircraft weight and balance. Incorrect or poorly verified cargo loading can affect aircraft CG, operational safety, turnaround efficiency, and fuel performance.

The system is designed to support ground and flight operations by:

- tracking cargo/ULD placement,
- calculating aircraft CG in %MAC,
- checking loading feasibility,
- identifying mismatches between planned and actual loading,
- recommending improved cargo arrangements,
- estimating the fuel-burn impact of CG movement,
- generating clearer visibility for loading teams and pilots.

The aim of this prototype is to demonstrate the core AIRLoad workflow. It is not intended to provide certified Airbus performance calculations.

To view the dashboard our prototype uses:-
Run this command : .\run_airload.bat from the repo root

Validation of model
To validate the model, we have used PHALANX which is a modular toolbox created by TU-DELFT. We have used it to calculate our fuel savings.
We have considered a sample flight plan from SIN to LHR and have calculated the fuel savings using dynamic conditions. To run it install the matlab extension and run this command:-

matlab -batch "cd('main/PHALANX_validation'); Phalanx_Analyse_Fuel_2"