import pandas as pd
import numpy as np
from ortools.sat.python import cp_model

def fetch_and_process(forecasted_orders_path,potential_utilization_path,buffer=1.0):
    #Import /                            This to be replaced with direct fetch from Snowflake once model is deployed
    forecasted_orders= pd.read_excel(forecasted_orders_path)
    potential_utilization= pd.read_excel(potential_utilization_path)

    #Equalise column names/              This to be eliminated as we allign direct fetch from Snowflake
    forecasted_orders.rename(columns= {'forecasted_orders': 'ForecastedOrders'}, inplace=True)
    potential_utilization.rename(columns= {'warehouse': 'Warehouse', 'city':'City', 'potenial_utilization': 'PotentialUtilization'  }, inplace=True)

    #Merge df and make riders
    temp= pd.merge(forecasted_orders,potential_utilization,on='Warehouse')
    temp['Riders']= np.ceil( (temp['ForecastedOrders']/temp['PotentialUtilization'])/buffer )
    temp = temp[ temp['Riders'].notna() ]
    temp = temp[ temp['PotentialUtilization'].notna() ]
    temp['Riders']= temp['Riders'].astype('int')
    base=temp
    
    return base

def define_skeleton():
    #Getting the basic structure from 'user'
    print('What are total number of shifts in your skeleton?')
    skeletonLength= int(input())
    skeleton=[]
    for i in range(0,skeletonLength):
        print('Please put start & end working hours of shift', (i+1), 'separated by a single comma "," ')
        hoursString= input()
        tempShift= hoursString.split(',')
        shift= list( map(int,tempShift) )
        skeleton.append(shift)
    
    #Creating basic dataframe, which will be used later to log the capacities as they're computed
    skeletonDf= pd.DataFrame(columns= ['EW','Date'])
    for i in skeleton:
        skeletonDf.insert( 
            (len(skeletonDf.columns))
            , f"capacity_shift_{i[0]}_{i[1]}"
            , None)
    
    return skeleton, skeletonDf

def mapping(base, skeleton, skeletonDf, output_path):

    #Used later in the capacity mapping part
    WarehouseList= base.Warehouse.unique()
    DateList= base.Date.unique()
    WarehouseDf=[]
    for i in WarehouseList:
        x=base[base.Warehouse==i]
        WarehouseDf.append(x[['Date','Hour','Warehouse','ForecastedOrders','Riders']])
    base=base[['Date','Hour','Warehouse','ForecastedOrders','PotentialUtilization']]

    #Mapping out capacities for each Date & EW
    for date in DateList:
        finalDfs=[]

        for warehouse in WarehouseDf:
            #Prep
            warehouse= warehouse[warehouse.Date== date]
            warehouse.sort_values(by='Hour', ascending= True, inplace=True)
            warehouse.index=warehouse.Hour
            warehouse.drop(columns='Hour', inplace = True)

            #Creating model & its variables
            model = cp_model.CpModel()
            model_variables=[]
            for i in range(0, len(skeleton)):
                model_variables.append( model.NewIntVar(
                    0, #This is the min limit of variable
                    int( 
                        np.max( warehouse.loc[np.min(skeleton[i]):np.max(skeleton[i])].Riders ) #This is max limit of variable
                        ),
                    f"capacity_shift_{skeleton[i][0]}_{skeleton[i][1]}"                    
                ))

            #Preparing constraints
                #Converting skeleton start/end time to hours
            skeleton_=[]
            for i in range(0, len(skeleton)):
                skeleton_.append(list(range(skeleton[i][0],skeleton[i][1]+1,1)))
            
                #Now, preparing constraints by comparing each shift hour with others in line
            constraints_updated=[]
            for i,shift in enumerate(skeleton_):
                sum=0
                for j,s in enumerate(skeleton_):
                        for hour in s:
                            if hour>=min(shift) and hour<=max(shift):
                                sum= sum+ model_variables[j]            
                constraints_updated.append(sum)
            
            #Adding constraints to model
            for i in range(0, len(skeleton)):
                model.Add( constraints_updated[i]>= int(
                    np.sum(
                        list( warehouse.loc[np.min(skeleton[i]):np.max(skeleton[i])].Riders )
                        )
                    )
                )
            
            #Adding the objective to minimize the number of capacities as much as possible while meeting constraints
            model.Minimize( ( (np.sum(constraints_updated)) ) )

            #Calling the model to solve
            #Note that output of each iteration is saved in a variable 'status' where '4' means a valid solution is found
            #If you get an error, it's mostly likely that model couldn't find a solution to your given variables and constraints
            #Check the value of status variable on failure. If it's other than 4, check your variables and constraints again
            solver = cp_model.CpSolver()
            status = solver.Solve(model)

            #Update columns in Warehouse Df to store capacities
            for i in skeleton:
                warehouse.insert( 
                    (len(warehouse.columns))
                    , f"capacity_shift_{i[0]}_{i[1]}"
                    , None)
            
            #DATA POPULATION
            contents=[(warehouse['Warehouse'][min(warehouse.index)]), date]
            for i in model_variables:
                contents.append(solver.Value(i))

            #Populate values in Warehouse Df
            for i,j in enumerate(skeleton_):
                for hour in j:
                    warehouse.loc[hour, str(model_variables[i]) ]= solver.Value(model_variables[i])
            finalDfs.append(warehouse)

            
                #Save into a sheet
            day= str(date).split('T')[0]
            writer = pd.ExcelWriter((output_path+f"output_details_{day}.xlsx"))
            for i in finalDfs:
                i.to_excel(writer, f'{i.loc[min(i.index)].Warehouse}')

            #Populate SkeletonDf
            skeletonDf.loc[ skeletonDf.shape[0] ]= contents

        writer.save()
        writer.close()
        writer.handles = None
        print('saving')
        print(skeletonDf)
        skeletonDf.to_excel(output_path+'output_summary.xlsx')
        print('saved')
