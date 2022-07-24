""" 
    - Provide path of forecasted orders or simply fetch forecasts from Db (Your preference)
        - Make sure that forecastedOrders are structured as follows in terms of columns: "Date", "Hour", "Warehouse", "ForecastedOrders"
        - Make sure that your forecastedOders are consistent
            If there is no forecast at particular hour, assume '0' as default instead of skipping the complete row
            Keep the number of EWs consistent and naming convention similar to that used in potential utilization
            Discrepancy here could lead to data loss as we merge the files later on. Keep the column names consistent
    
    - Provide path of potential utilization or simply fetch potential utilization from Db (Your preference)
        Make sure that potential utilization file is structured as follows in terms of columns: "Warehouse", "City", "PotentialUtilization"
        Discrepancy here could lead to data loss as we merge the files later on. Keep the column names consistent
        
    - Output path will be used to populate files. Make sure you've valid path and folder.
"""

#Path
    #Format of files
        #Orders: Hour	Warehouse	forecasted_orders	Date
        #PU:     warehouse	city	potenial_utilization

forecasted_orders_path=r"sample_ orders.xlsx".replace('\\','/')
potential_utilization_path=r"sample_utilization.xlsx".replace('\\','/')
#output path used later to save all files from all skeletons
output_path= ""


