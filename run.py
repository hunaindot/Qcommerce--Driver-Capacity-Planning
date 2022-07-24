from constants import *
from helpers import *

def run():
    base= fetch_and_process(forecasted_orders_path,potential_utilization_path) #Buffer=1 by default in this; pass buffer (1-buffer %) to create some
    skeleton, skeletonDf=define_skeleton() #It takes input of skeleton at run time
    mapping(base, skeleton, skeletonDf, output_path)

if __name__=='__main__':
    run()