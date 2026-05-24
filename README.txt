# AIRLoad for Airbus

AIRLoad is an aircraft cargo loading verification and decision-support prototype designed for Airbus wide-body operations, mainly the **A350-1000**. It helps improve aircraft loading accuracy by comparing the planned cargo load with the actual loading state, calculating aircraft centre of gravity (CG), and flagging unsafe or inefficient loading conditions.

The prototype demonstrates how **digital twin logic** and **AI-assisted loading recommendations** can be integrated into one aircraft loading workflow.

---

## Project Overview

AIRLoad addresses a real operational challenge in aircraft weight and balance. Incorrect or poorly verified cargo loading can affect aircraft CG, operational safety, turnaround efficiency, and fuel performance.

The system is designed to support ground and flight operations by:

- Tracking cargo/ULD placement
- Calculating aircraft CG in **%MAC**
- Checking loading feasibility
- Identifying mismatches between planned and actual loading
- Recommending improved cargo arrangements
- Validating the model using the fuel-burn impact of CG movement *(validated on a 13.5-hour flight plan)*
- Generating clearer visibility for loading teams and pilots

> **Note:** The aim of this prototype is to demonstrate the core AIRLoad workflow. It is not intended to provide certified Airbus performance calculations.

---

## Setup

Ensure **Python**, **MATLAB**, and **Git** are installed by running the following in PowerShell:

```powershell
python --version
matlab --version
git --version
```

---

## Running the Dashboard

From the repo root, run:

```powershell
.\run_airload.bat
```

> Sample flight plans are provided under the `interface` directory and can be used as test inputs for the dashboard.

---

## Model Validation

Validation is performed using **PHALANX**, a modular toolbox created by **TU Delft**, to calculate fuel savings.

A sample flight plan from **SIN → LHR** was used to calculate fuel savings under dynamic conditions.

To run the validation, install the MATLAB extension and execute the following from the repo root:

```powershell
matlab -batch "cd('main/PHALANX_validation'); Phalanx_Analyse_Fuel_2"
```
