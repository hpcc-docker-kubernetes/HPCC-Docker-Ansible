#!/usr/bin/python
import sys
import getopt
import json
import os.path



class ClusterConfig(object):

  def __init__(self):
     '''
     Constructor
     '''

     self.fn   = "/tmp/pods.json"
     self.dir  = "/tmp"

  def usage(self):
    print("Usage get_ips.py [option(s)]\n")
    print(" -f --file        input json file name")
    print(" -d --directory   output directoryi. The default is /tmp ")
    print("\n");

  def process_args(self):
    try:
      opts, args = getopt.getopt(sys.argv[1:],":c:e:f:h:l:n:o:s:x",
        ["help", "chksum","env_conf","script_file","host_list", "number_of_threads",
        "section", "log_file", "log_level", "exclude_local"])

    except getopt.GetoptError as err:
      print(str(err))
      self.usage()
      exit(0)

    for arg, value in opts:
      if arg in ("-?", "--help"):
        self.usage()
        exit(0)
      elif arg in ("-f", "--file"):
        self.fn = value
      elif arg in ("-d", "--directory"):
        self.dir = value


  def group_ips(self):

    if not self.fn or not os.path.exists(self.fn): 
      self.usage()
      exit(1)

    with open(self.fn) as hpcc_pods:
      data = json.load(hpcc_pods)

    roxie_ips_file = "roxie_ips.txt"
    f_dali_ips  = open (os.path.join(self.dir, 'ips/dali'), 'w')
    f_roxie_ips = open (os.path.join(self.dir, 'ips/roxie'), 'w')
    f_thor_ips  = open (os.path.join(self.dir, 'ips/thor'), 'w')
    f_esp_ips   = open (os.path.join(self.dir, 'ips/esp'),  'w')
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

if __name__ == '__main__':

  cc = ClusterConfig()
  cc.process_args()
  cc.group_ips()

