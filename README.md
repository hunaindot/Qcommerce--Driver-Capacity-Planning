# Qcommerce--Driver-Capacity-Planning

## Business Problem
In Qcommerce industry, the companies operate multiple hyper local dark store which are leveraged to deliver orders quickly. At scales, there are multiple properties held by a company for each defined working zones. In this situation, how should a business allocate just enough amount of Riders/ Drivers so that (a) all the orders are delivered on time and (b) Riders/ Drivers are utilized most for cost efficiency. 

Hence, for every Qcommerce, there is need for solution that takes **inputs** of order flow expectation and shift working timings to **return** an optimal count of drivers to be placed at each problem.

## How can you run this locally?
1. Download the repository & open the folder with any editor- perferably VS Code
2. Use the "requirements.txt" file to install all the necessary versions of libraries.
3. Execute the run.py file
4. Output: In your root file, you can see a sample output being populated as two .xlsx files

Ps. There's a module named constants.py where you can change your forecast_order flow & utilization (Productivity target in terms of orders completed / hr) for your set of targets. By default, we're using sample files here.

## How this repository attempts to solve the problem

**Required Riders Calculation**

With the input of order flow at each hour for a property or "Warehouse", this repository calculates the required riders at each hour for that zone (Order Flow / Productivity or Utilization benchmark).

**Getting input of working shift structure**

Next, given a dataframe of Warehouse + Hours + Dates + Required Riders, the solution takes an input of how the workings hour are to be distributed:
      - Depending on location, there could be drivers working in different shift and hours; the solution takes input of working shift structure
      
**Setting up optimization question**
Combined the required riders and a working shift structure, this become as **linear optimiation problem**: _With the objective to minimize the allocation of riders at each property, how should the riders be allocated to each property at each shift working hours- meeting the constraint that any property doesn't go under-supplied at any hour wrt the required riders count_

**Finding feasible solution**

With the help of google's OR Tools, we've set up the problem mathematically in helpers.py module- where constraints and objective functions are prepared to return the solution.

**Output Format**

The process at the end returns two .xlsx files as output: 
  (i)  Output Summary: This contains the summary of what rider should be allocated for each date and defined distribution of working shifts.
  (ii) Output Details: This contains a detailed view of how does the demand and allocation look like at each property- seggregated by separate sheets for each property
  


