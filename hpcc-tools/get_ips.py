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

  def write_to_file(self, base_dir, comp_type, ip):

      file_name = os.path.join(base_dir, comp_type)

      if os.path.exists(file_name):
        f_ips  = open (file_name, 'a')
      else:
        f_ips  = open (file_name, 'w')
    
      f_ips.write(ip + "\n")
      f_ips.close()

  def clean_dir(self, dir):
    for f in os.listdir(dir):
      f_path = os.path.join(dir, f) 
      try:
         if os.path.isfile(f_path):
           os.unlink(f_path)
      except Exception as e:
         print(e) 
        

  def group_pod_ips(self):

    if not self.pod_fn or not os.path.exists(self.pod_fn): 
      self.usage()
      exit(1)

    with open(self.pod_fn) as hpcc_pods:
      data = json.load(hpcc_pods)

    
    self.clean_dir(self.pod_dir)

    for item in data['items']:
      #for c in  item['spec']['containers']:
      #   print c['name']
      if item['metadata']['name'].startswith('roxie'):
        self.write_to_file(self.pod_dir, 'roxie', item['status']['podIP'])
      elif item['metadata']['name'].startswith('thor'):
        self.write_to_file(self.pod_dir, 'thor', item['status']['podIP'])
      elif item['metadata']['name'].startswith('esp'):
        self.write_to_file(self.pod_dir, 'esp', item['status']['podIP'])
      elif item['metadata']['name'].startswith('dali'):
        self.write_to_file(self.pod_dir,'dali', item['status']['podIP'])

  def group_svc_ips(self):

    if not self.svc_fn or not os.path.exists(self.svc_fn): 
      #self.usage()
      #exit(1)
      return

    with open(self.svc_fn) as hpcc_services:
      data = json.load(hpcc_services)

    self.clean_dir(self.svc_dir)

    for item in data['items']:
      #for c in  item['spec']['containers']:
      #   print c['name']
      if item['metadata']['name'].startswith('roxie'):
        self.write_to_file(self.svc_dir, 'roxie', item['spec']['clusterIP'])
      elif item['metadata']['name'].startswith('thor'):
        self.write_to_file(self.svc_dir, 'thor', item['spec']['clusterIP'])
      elif item['metadata']['name'].startswith('esp'):
        self.write_to_file(self.svc_dir, 'esp', item['spec']['clusterIP'])
      elif item['metadata']['name'].startswith('dali'):
        self.write_to_file(self.svc_dir, 'dali', item['spec']['clusterIP'])


if __name__ == '__main__':

  cc = ClusterConfig()
  cc.process_args()
  cc.group_pod_ips()
  cc.group_svc_ips()

