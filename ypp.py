#!/usr/bin/env python3
import base64
import yaml
import sys
import re
import os

###################################################################
#
# YAML related utilities
#
###################################################################
yaml_include_path = []
yaml_pp_vars = dict(os.environ)

valid_re = re.compile(r'^[A-Za-z][A-Za-z0-9]*$')

def yaml_init(inc_path, predef):
  if inc_path:
    for inc in inc_path:
      if os.path.isdir(inc):
        yaml_include_path.append(inc)
  if predef:
    for kvp in predef:
      if '=' in kvp:
        kvp = kvp.split('=',1)
        key = kvp[0]
        val = kvp[1]
      else:
        key = kvp
        val = ''
      if valid_re.match(key):
        yaml_pp_vars[key] = val
      else:
        print('{} is not a valid name'.format(key))

def yaml_findfile(fname, prev):
  if fname[0] == '/':
    # This is an absolute path!
    return fname

  if prev:
    dn = os.path.dirname(prev)
    if dn == '':
      tname = fname
    else:
      tname = '{}/{}'.format(dn,fname)
    if os.path.isfile(tname): return tname

  for dn in yaml_include_path:
    tname = '{}/{}'.format(dn,fname)
    if os.path.isfile(tname): return tname

  # Otherwise just hope for the best!
  return fname

include_res = [ re.compile(r'^(\s*)#\s*include\s+') , re.compile(r'^(\s*-\s*)#\s*include\s+')]
include_type = re.compile(r'\s*--(raw|bin)\s+')

def yaml_inc(line):
  for inc_re in include_res:
    mv = inc_re.match(line)
    if mv is None: continue

    fname = line[mv.end():]
    prefix = mv.group(1)

    mv = include_type.match(fname)
    if mv:
      fname = fname[mv.end():]
      inctype = mv.group(1)
    else:
      inctype = None
    return { 'file': fname, 'prefix': prefix, 'type': inctype }
  return None

def yaml_raw(fname, prefix = '', prev = None):
  txt = ''
  prefix2 = prefix.replace('-',' ')
  fname = yaml_findfile(fname, prev)

  with open(fname,'r') as f:
    for line in f:
      if line.endswith("\n"): line = line[:-1]
      if line.endswith("\r"): line = line[:-1]
      txt += prefix + line + "\n"
      prefix = prefix2

  return txt

def yaml_bin(fname, prefix = '', prev = None):
  txt = ''
  prefix2 = prefix.replace('-',' ')
  fname = yaml_findfile(fname, prev)

  with open(fname,'rb') as f:
    b64 = base64.b64encode(f.read()).decode('ascii')
    i = 0
    while i < len(b64):
      txt += prefix + b64[i:i+76] + "\n"
      prefix = prefix2
      i += 76

  return txt

define_re = re.compile(r'^\s*#\s*define\s+([A-Za-z][A-Za-z0-9]*)\s*')
def yaml_pp(fname, prefix = '', prev = None):
  txt = ''
  prefix2 = prefix.replace('-',' ')

  fname = yaml_findfile(fname, prev)

  with open(fname,'r') as f:
    for line in f:
      if line.endswith("\n"): line = line[:-1]
      if line.endswith("\r"): line = line[:-1]
      mv = define_re.match(line)
      if mv:
        yaml_pp_vars[mv.group(1)] = line[mv.end():].format(**yaml_pp_vars)
        continue

      mv = yaml_inc(line)
      if mv:
        if mv['type'] == 'raw':
          txt += yaml_raw(mv['file'], prefix = mv['prefix'], prev=fname)
        elif mv['type'] == 'bin':
          txt += yaml_bin(mv['file'], prefix = mv['prefix'], prev=fname)
        else:
          txt += yaml_pp(mv['file'], prefix = mv['prefix'], prev=fname)
        continue

      txt += prefix + line.format(**yaml_pp_vars) + "\n"
      prefix = prefix2

  return txt

def yparse_cmd(args):
  if args.yaml:
    if args.preproc:
      yaml_init(args.include, args.define)
      ytxt = yaml_pp(args.file)
    else:
      ytxt = open(args.file, 'r')
    res = yaml.safe_load(ytxt)
    print(res)
  else:
    yaml_init(args.include, args.define)
    txt = yaml_pp(args.file)
    print(txt)

def dump(data):
  return yaml.dump(data)

def process(yamlfile, includes, defines):
  yaml_init(includes, defines)
  return yaml.safe_load(yaml_pp(yamlfile))

def load(thing):
  return yaml.safe_load(thing)

###################################################################
#
# Main command line
#
###################################################################

if __name__ == '__main__':
  from argparse import ArgumentParser, Action

  cli = ArgumentParser(prog='ypp',description='YAML file pre-processor')
  cli.add_argument('-I','--include', help='Add Include path', action='append')
  cli.add_argument('-D','--define', help='Add constant', action='append')

  cli.add_argument('-y','--yaml', help='Parse YAML',action='store_true')
  cli.add_argument('-p','--preproc', help='Use pre-processor when parsing yaml',action='store_true')
  cli.add_argument('file', help='YAML file to parse')

  args = cli.parse_args()
  yparse_cmd(args)
  sys.exit()
