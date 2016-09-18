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

     self.pod_fn   = "/tmp/pods.json"
     self.svc_fn   = "/tmp/services.json"
     self.pod_dir  = "/tmp/ips"
     self.svc_dir  = "/tmp/lb-ips"

  def usage(self):
    print("Usage get_ips.py [option(s)]\n")
    print(" -i --poddir     output pod ip directory. The default is /tmp/ips ")
    print(" -l --svcdir     output service ip directory. The default is /tmp/lb-ips ")
    print(" -p --podfile    input pod json file name")
    print(" -s --svcfile    input service json file name")
    print("\n");

  def process_args(self):
    try:
      opts, args = getopt.getopt(sys.argv[1:],":i:l:p:s:h",
        ["help", "poddir","svcdir","podfile","svcfile" ])

    except getopt.GetoptError as err:
      print(str(err))
      self.usage()
      exit(0)

    for arg, value in opts:
      if arg in ("-?", "--help"):
        self.usage()
        exit(0)
      elif arg in ("-p", "--podfile"):
        self.pod_fn = value
      elif arg in ("-s", "--svcfile"):
        self.svc_fn = value
      elif arg in ("-i", "--poddir"):
        self.pod_dir = value
      elif arg in ("-l", "--svcdir"):
        self.svc_dir = value

  def group_pod_ips(self):

    if not self.pod_fn or not os.path.exists(self.pod_fn): 
      self.usage()
      exit(1)

    with open(self.pod_fn) as hpcc_pods:
      data = json.load(hpcc_pods)

    #roxie_ips_file = "roxie_ips.txt"
    f_dali_ips  = open (os.path.join(self.pod_dir, 'dali'), 'w')
    f_roxie_ips = open (os.path.join(self.pod_dir, 'roxie'), 'w')
    f_thor_ips  = open (os.path.join(self.pod_dir, 'thor'), 'w')
    f_esp_ips   = open (os.path.join(self.pod_dir, 'esp'),  'w')
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

  def group_svc_ips(self):

    if not self.svc_fn or not os.path.exists(self.svc_fn): 
      self.usage()
      exit(1)

    with open(self.svc_fn) as hpcc_services:
      data = json.load(hpcc_services)

    f_dali_ips  = open (os.path.join(self.svc_dir, 'dali'), 'w')
    f_roxie_ips = open (os.path.join(self.svc_dir, 'roxie'), 'w')
    f_thor_ips  = open (os.path.join(self.svc_dir, 'thor'), 'w')
    f_esp_ips   = open (os.path.join(self.svc_dir, 'esp'),  'w')
    for item in data['items']:
      #for c in  item['spec']['containers']:
      #   print c['name']
      if item['metadata']['name'].startswith('roxie'):
        f_roxie_ips.write(item['spec']['clusterIP'] + "\n")
      elif item['metadata']['name'].startswith('thor'):
        f_thor_ips.write(item['spec']['clusterIP'] + "\n")
      elif item['metadata']['name'].startswith('esp'):
        f_esp_ips.write(item['spec']['clusterIP'] + "\n")
      elif item['metadata']['name'].startswith('dali'):
        f_dali_ips.write(item['spec']['clusterIP'] + "\n")

    f_dali_ips.close()
    f_roxie_ips.close()
    f_thor_ips.close()
    f_esp_ips.close()

if __name__ == '__main__':

  cc = ClusterConfig()
  cc.process_args()
  cc.group_pod_ips()
  cc.group_svc_ips()

