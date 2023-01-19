SET hive.groupby.position.alias=true;
DROP TABLE IF EXISTS SR_DEX2 ;
CREATE TABLE SR_DEX2 LIFECYCLE 1 AS

SELECT  a.venture
	,REPLACE(courier_name,",","-")
	,a.current_lm_node_name
        ,a.shipping_type 
        ,CASE WHEN a.origin_type = 'Crossborder' THEN 'Crossborder'
              ELSE a.shipping_type END AS Shipping_Catgegory
        ,a.fulfillment_type
        ,a.origin_type
        ,a.fm_3pl_name as FMSP
        ,a.shipping_provider_name as LMSP
        ,a.lvl1_current_status 
        ,tracking_number
        ,package_id
        ,terminal_status
        ,destination_city
        ,created_date as order_created_at
        ,shipped_date
        ,delivered_date as delivered_updated
        ,delivery_failed_updated
        ,seller_type
        ,CASE WHEN lvl1_current_status = 'delivered' THEN 1 ELSE 0 END as Delivered_Packages
FROM(
SELECT  venture
		,courier_name
		,current_lm_node_name
        ,c.origin_type
        -- Add condition for sr2 logic to be applicable from 1st April (YF 20210607)
        -- Update package status logic to match sr2 (YF 20210528)
        ,CASE WHEN lvl1_current_status = 'delivered' THEN delivered_date
			WHEN lvl1_current_status = 'package_cancelled' THEN coalesce(closed.cancelled_updated,closed_old.cancelled_updated)
			WHEN lvl1_current_status = 'delivery_failed' THEN delivery_failed_updated
			WHEN lvl1_current_status IN ('package_closed','package_scrapped','package_damaged','package_lost') AND delivered_date IS NOT NULL AND delivered_date < coalesce(closed.closed_updated,closed_old.closed_updated) THEN delivered_date
			WHEN lvl1_current_status IN ('package_closed','package_scrapped','package_damaged','package_lost') AND delivery_failed_updated IS NOT NULL AND delivery_failed_updated < coalesce(closed.closed_updated,closed_old.closed_updated) THEN delivery_failed_updated
			WHEN lvl1_current_status IN ('package_closed','package_scrapped','package_damaged','package_lost') THEN coalesce(closed.closed_updated,closed_old.closed_updated)
			WHEN COALESCE(delivery_failed_updated,back_to_shipper,returned_to_shipper) < '2022-01-01 00:00:00' THEN delivery_failed_updated
			ELSE COALESCE(delivery_failed_updated,back_to_shipper,returned_to_shipper) END as terminal_status
        ,c.package_type
        ,c.package_id
        ,fulfillment_type
        ,shipping_type 
        ,payment_type
        ,reship_flag
        ,c.tracking_number
        ,destination_city
        ,fm_3pl_name
        ,lm_3pl_name
        ,shipping_provider_name
        ,lvl1_current_status
        ,created_date
        ,shipped_date
        ,delivered_date
        ,delivery_failed_updated
        ,seller_type
FROM (
SELECT   venture
		,courier_name
		,current_lm_node_name
        ,package_type
        ,package_id
        ,origin_type AS origin_type
        ,shipping_type AS shipping_type
        ,CASE   WHEN payment_type LIKE '%COD%' THEN 'COD'
                ELSE 'Prepaid' END as payment_type
        ,reship_flag
        ,tracking_number
        ,fulfillment_type
        ,fm_3pl_name
        ,lm_3pl_name
        ,CASE   
                WHEN venture <> 'LK' AND (lm_3pl_name LIKE '%DEX%' OR lm_3pl_name LIKE '%MM-ShopEX%') THEN 'DEX'
                WHEN venture = 'LK' AND lm_3pl_name LIKE '%DEX%' AND lm_node_name NOT IN ('APR','BAT','POL','HAT','JFR','LK-LMP-KES','KMO','ANU','LK-LMP-SNT','HMB','MLT','NSA','GAL','DAM','NPT','MON','NSI','MTL') THEN 'DEX'
                WHEN lm_3pl_name LIKE '%Forree%' or lm_3pl_name like '%For-WH%' THEN 'DEX'
                WHEN lm_3pl_name LIKE '%LMP%' THEN 'LMP' 
                WHEN venture = 'LK' AND lm_3pl_name LIKE '%DEX%' AND lm_node_name IN ('APR','BAT','POL','HAT','JFR','LK-LMP-KES','KMO','ANU','LK-LMP-SNT','HMB','MLT','NSA','GAL','DAM','NPT','MON','NSI','MTL') THEN 'LMP'
                ELSE '3PL' END AS shipping_provider_name
        ,lvl1_current_status
        ,lvl2_destination_address_name
        ,CASE   WHEN lvl3_destination_address_name LIKE '%Colombo%' THEN 'Colombo'
                WHEN lvl3_destination_address_name LIKE '%Kathmandu%' THEN 'Kathmandu' 
                WHEN lvl3_destination_address_name LIKE '%Lalitpur%' THEN 'Lalitpur'
                WHEN lvl3_destination_address_name LIKE '%Landikotal%' THEN 'Landikotal'
                ELSE substring_index(lvl3_destination_address_name, '-', 1) END as destination_city
        ,CASE   when venture = 'BD' THEN from_unixtime(unix_timestamp(order_creation_ts) - 2 * 3600)
                when venture = 'LK' THEN from_unixtime(unix_timestamp(order_creation_ts) - 2.5 * 3600)
                when venture = 'MM' THEN from_unixtime(unix_timestamp(order_creation_ts) - 1.5 * 3600)
                when venture = 'NP' THEN from_unixtime(unix_timestamp(order_creation_ts) - 2.25 * 3600)
                when venture = 'PK' THEN from_unixtime(unix_timestamp(order_creation_ts) - 3 * 3600)
                ELSE NULL END as created_date
        ,CASE   when venture = 'BD' THEN from_unixtime(unix_timestamp(lvl2_in_success_in_sort_center_ts) - 2 * 3600)
                when venture = 'LK' THEN from_unixtime(unix_timestamp(lvl2_in_success_in_sort_center_ts) - 2.5 * 3600)
                when venture = 'MM' THEN from_unixtime(unix_timestamp(lvl2_in_success_in_sort_center_ts) - 1.5 * 3600)
                when venture = 'NP' THEN from_unixtime(unix_timestamp(lvl2_in_success_in_sort_center_ts) - 2.25 * 3600)
                when venture = 'PK' THEN from_unixtime(unix_timestamp(lvl2_in_success_in_sort_center_ts) - 3 * 3600)
                ELSE NULL END as sort_date
        ,CASE   when venture = 'BD' THEN from_unixtime(unix_timestamp(COALESCE(lvl1_shipped_ts)) - 2 * 3600)
                when venture = 'LK' THEN from_unixtime(unix_timestamp(COALESCE(lvl1_shipped_ts)) - 2.5 * 3600)
                when venture = 'MM' THEN from_unixtime(unix_timestamp(COALESCE(lvl1_shipped_ts)) - 1.5 * 3600)
                when venture = 'NP' THEN from_unixtime(unix_timestamp(COALESCE(lvl1_shipped_ts)) - 2.25 * 3600)
                when venture = 'PK' THEN from_unixtime(unix_timestamp(COALESCE(lvl1_shipped_ts)) - 3 * 3600)
                ELSE NULL END as shipped_date
        ,CASE   when venture = 'BD' THEN from_unixtime(unix_timestamp(COALESCE(lvl1_delivered_updated_ts)) - 2 * 3600)
                when venture = 'LK' THEN from_unixtime(unix_timestamp(COALESCE(lvl1_delivered_updated_ts)) - 2.5 * 3600)
                when venture = 'MM' THEN from_unixtime(unix_timestamp(COALESCE(lvl1_delivered_updated_ts)) - 1.5 * 3600)
                when venture = 'NP' THEN from_unixtime(unix_timestamp(COALESCE(lvl1_delivered_updated_ts)) - 2.25 * 3600)
                when venture = 'PK' THEN from_unixtime(unix_timestamp(COALESCE(lvl1_delivered_updated_ts)) - 3 * 3600)
                ELSE NULL END as delivered_date
        ,CASE   when venture = 'BD' THEN from_unixtime(unix_timestamp(lvl1_delivery_failed_updated_ts) - 2 * 3600)
                when venture = 'LK' THEN from_unixtime(unix_timestamp(lvl1_delivery_failed_updated_ts) - 2.5 * 3600)
                when venture = 'MM' THEN from_unixtime(unix_timestamp(lvl1_delivery_failed_updated_ts) - 1.5 * 3600)
                when venture = 'NP' THEN from_unixtime(unix_timestamp(lvl1_delivery_failed_updated_ts) - 2.25 * 3600)
                when venture = 'PK' THEN from_unixtime(unix_timestamp(lvl1_delivery_failed_updated_ts) - 3 * 3600)
                ELSE NULL END as delivery_failed_updated
		,CASE   when venture = 'BD' THEN from_unixtime(unix_timestamp(COALESCE(lvl1_returned_to_shipper_updated_ts)) - 2 * 3600)
                when venture = 'LK' THEN from_unixtime(unix_timestamp(COALESCE(lvl1_returned_to_shipper_updated_ts)) - 2.5 * 3600)
                when venture = 'MM' THEN from_unixtime(unix_timestamp(COALESCE(lvl1_returned_to_shipper_updated_ts)) - 1.5 * 3600)
                when venture = 'NP' THEN from_unixtime(unix_timestamp(COALESCE(lvl1_returned_to_shipper_updated_ts)) - 2.25 * 3600)
                when venture = 'PK' THEN from_unixtime(unix_timestamp(COALESCE(lvl1_returned_to_shipper_updated_ts)) - 3 * 3600)
                ELSE NULL END as returned_to_shipper
		,CASE   when a.venture = 'BD' THEN from_unixtime(unix_timestamp(lvl1_on_the_way_back_to_shipper_ts) - 2 * 3600)
                when a.venture = 'LK' THEN from_unixtime(unix_timestamp(lvl1_on_the_way_back_to_shipper_ts) - 2.5 * 3600)
                when a.venture = 'MM' THEN from_unixtime(unix_timestamp(lvl1_on_the_way_back_to_shipper_ts) - 1.5 * 3600)
                when a.venture = 'NP' THEN from_unixtime(unix_timestamp(lvl1_on_the_way_back_to_shipper_ts) - 2.25 * 3600)
                when a.venture = 'PK' THEN from_unixtime(unix_timestamp(lvl1_on_the_way_back_to_shipper_ts) - 3 * 3600)
                ELSE NULL END as back_to_shipper
        ,CASE    WHEN seller_name LIKE '%Sourceco%' THEN 'DFresh/Sourceco'
                 WHEN seller_name LIKE '%SourceCo%' THEN 'DFresh/Sourceco'
                 WHEN seller_name LIKE '%DFresh%' THEN 'DFresh/Sourceco'
                 WHEN seller_name LIKE '%Laughs Supermarket%' THEN 'DFresh/Sourceco'
                 WHEN seller_name LIKE '%Colombo WH SourceCo%' THEN 'DFresh/Sourceco' 
                 ELSE 'Normal' END AS seller_type
        FROM         drzops_cdm.dwd_drz_lgt_dlv_pkg_df a

        WHERE   ds = to_char(dateadd(GETDATE(), - WEEKDAY(GETDATE()) - 1, 'dd'),'YYYYMMDD')
        -- Changes for optimization
        AND     is_pre_apollo = 0
        --clause to include other statuses which were aggregated to package closed previously
        AND     TOLOWER(a.lvl1_current_status) in ('delivery_failed','package_closed','delivered','returned_to_shipper','on_the_way_back_to_shipper','package_scrapped','package_damaged','package_lost') 
        ) as c
        LEFT JOIN 
        (     SELECT  package_number
                      ,MAX(CASE WHEN business_area = 'Crossborder' THEN 1 ELSE 0 END) as origin_type
                      ,count(package_number) as item
              FROM    daraz_cdm.dwd_drz_trd_core_df t
              WHERE   ds = to_char(dateadd(GETDATE(), - WEEKDAY(GETDATE()) - 1, 'dd'),'YYYYMMDD')
              GROUP BY package_number) cb
        ON      c.package_id = cb.package_number

-- Add condition for sr2 logic to be applicable from 1st April (YF 20210607)
-- Update package status logic to match sr2 (YF 20210527)
        LEFT JOIN (SELECT   unit_code
                    --clause to include other statuses which were aggregated to package closed previously (YF 20210527)
                    ,min(CASE   when action = 'package_closed' AND venture = 'BD' THEN from_unixtime(unix_timestamp(create_at) - 2 * 3600)
                                when action = 'package_closed' AND venture = 'LK' THEN from_unixtime(unix_timestamp(create_at) - 2.5 * 3600)
                                when action = 'package_closed' AND venture = 'MM' THEN from_unixtime(unix_timestamp(create_at) - 1.5 * 3600)
                                when action = 'package_closed' AND venture = 'NP' THEN from_unixtime(unix_timestamp(create_at) - 2.25 * 3600)
                                when action = 'package_closed' AND venture = 'PK' THEN from_unixtime(unix_timestamp(create_at) - 3 * 3600)
                                when action in ('package_scrapped','package_damaged','package_lost')  AND venture = 'BD' AND from_unixtime(unix_timestamp(create_at) - 2 * 3600) >= '2021-04-01 00:00:00' THEN from_unixtime(unix_timestamp(create_at) - 2 * 3600)
                                when action in ('package_scrapped','package_damaged','package_lost')  AND venture = 'LK' AND from_unixtime(unix_timestamp(create_at) - 2.5 * 3600) >= '2021-04-01 00:00:00' THEN from_unixtime(unix_timestamp(create_at) - 2.5 * 3600)
                                when action in ('package_scrapped','package_damaged','package_lost')  AND venture = 'MM' AND from_unixtime(unix_timestamp(create_at) - 1.5 * 3600) >= '2021-04-01 00:00:00' THEN from_unixtime(unix_timestamp(create_at) - 1.5 * 3600)
                                when action in ('package_scrapped','package_damaged','package_lost')  AND venture = 'NP' AND from_unixtime(unix_timestamp(create_at) - 2.25 * 3600) >= '2021-04-01 00:00:00' THEN from_unixtime(unix_timestamp(create_at) - 2.25 * 3600)
                                when action in ('package_scrapped','package_damaged','package_lost')  AND venture = 'PK' AND from_unixtime(unix_timestamp(create_at) - 3 * 3600) >= '2021-04-01 00:00:00' THEN from_unixtime(unix_timestamp(create_at) - 3 * 3600)
                                ELSE NULL END) as closed_updated 
                    ,min(CASE   when action = 'package_cancelled'  AND venture = 'BD' THEN from_unixtime(unix_timestamp(create_at) - 2 * 3600)
                                when action = 'package_cancelled'  AND venture = 'LK' THEN from_unixtime(unix_timestamp(create_at) - 2.5 * 3600)
                                when action = 'package_cancelled'  AND venture = 'MM' THEN from_unixtime(unix_timestamp(create_at) - 1.5 * 3600)
                                when action = 'package_cancelled'  AND venture = 'NP' THEN from_unixtime(unix_timestamp(create_at) - 2.25 * 3600)
                                when action = 'package_cancelled'  AND venture = 'PK' THEN from_unixtime(unix_timestamp(create_at) - 3 * 3600)
                                ELSE NULL END) as cancelled_updated
            FROM   drzops_cdm.dwd_drz_lgt_pkg_status_history_h
            --clause to include other statuses which were aggregated to package closed previously (YF 20210527)
            WHERE  action in ('package_closed','package_cancelled','package_scrapped','package_damaged','package_lost')
                               
            AND     ds = to_char(dateadd(GETDATE(), - WEEKDAY(GETDATE()) - 0, 'dd'),'YYYYMMDD') AND hh = '03'
            GROUP BY unit_code) closed
            ON c.package_id = closed.unit_code

        LEFT JOIN (SELECT   package_id
                    ,min(CASE   when status = 'package_closed'  AND venture = 'BD' THEN from_unixtime(unix_timestamp(created_at) - 2 * 3600)
                                when status = 'package_closed'  AND venture = 'LK' THEN from_unixtime(unix_timestamp(created_at) - 2.5 * 3600)
                                when status = 'package_closed'  AND venture = 'MM' THEN from_unixtime(unix_timestamp(created_at) - 1.5 * 3600)
                                when status = 'package_closed'  AND venture = 'NP' THEN from_unixtime(unix_timestamp(created_at) - 2.25 * 3600)
                                when status = 'package_closed'  AND venture = 'PK' THEN from_unixtime(unix_timestamp(created_at) - 3 * 3600)
                                ELSE NULL END) as closed_updated 
                    ,min(CASE   when status = 'package_cancelled'  AND venture = 'BD' THEN from_unixtime(unix_timestamp(created_at) - 2 * 3600)
                                when status = 'package_cancelled'  AND venture = 'LK' THEN from_unixtime(unix_timestamp(created_at) - 2.5 * 3600)
                                when status = 'package_cancelled'  AND venture = 'MM' THEN from_unixtime(unix_timestamp(created_at) - 1.5 * 3600)
                                when status = 'package_cancelled'  AND venture = 'NP' THEN from_unixtime(unix_timestamp(created_at) - 2.25 * 3600)
                                when status = 'package_cancelled'  AND venture = 'PK' THEN from_unixtime(unix_timestamp(created_at) - 3 * 3600)
                                ELSE NULL END) as cancelled_updated
            FROM   drzops_cdm.s_tms_package_status_history_h
            WHERE  status in ('package_closed','package_cancelled')
                               
            AND     ds = to_char(dateadd(GETDATE(), - WEEKDAY(GETDATE()) - 0, 'dd'),'YYYYMMDD') AND hh = '03'
            GROUP BY package_id) closed_old
            ON c.package_id = closed_old.package_id
        
        ) a

WHERE   a.package_type = 'Sales_order'
AND     seller_type = 'Normal'
AND     terminal_status >= datetrunc(dateadd(GETDATE(), - WEEKDAY(GETDATE()) - 7, 'dd'),'dd')
AND     terminal_status <= datetrunc(dateadd(GETDATE(), - WEEKDAY(GETDATE()) - 0, 'dd'),'dd')
;

tunnel download SR_DEX2 dump\DEX\SuccessRate_Terminal.csv -tz Asia/Singapore -h true;
