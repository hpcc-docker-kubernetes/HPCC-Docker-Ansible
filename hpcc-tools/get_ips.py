#!/usr/bin/python
import sys
import json

if len(sys.argv) > 1:
   fn = sys.argv[1]
else:
   fn = "pods.json"

with open(fn) as hpcc_pods:
    data = json.load(hpcc_pods)

roxie_ips_file = "roxie_ips.txt"
f_dali_ips = open ('/tmp/ips/dali', 'w')
f_roxie_ips = open ('/tmp/ips/roxie', 'w')
f_thor_ips = open ('/tmp/ips/thor', 'w')
f_esp_ips = open ('/tmp/ips/esp', 'w')
for item in data['items']:
   #for c in  item['spec']['containers']:
   #   print c['name']

   if item['metadata']['name'].startswith('roxie'):
     f_roxie_ips.write(item['status']['podIP'] + "\n")
   elif item['metadata']['name'].startswith('thor'):
     f_thor_ips.write(item['status']['podIP'] + "\n")
   elif item['metadata']['name'].startswith('esp'):
     f_esp_ips.write(item['status']['podIP'] + "\n")
   elif item['metadata']['name'].startswith('dali'):
     f_dali_ips.write(item['status']['podIP'] + "\n")


f_dali_ips.close()
f_roxie_ips.close()
f_thor_ips.close()
f_esp_ips.close()
