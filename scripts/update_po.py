import os, re, mmap

import sys

po_table={}
po_string_table={}
plur_po_string_table={}
lang_path="decompressed/gui_file/www/lang"

normal_po_regex = re.compile(r"(?<=msgid\s)\".*?(?<!\\)\"(?=\s+msgstr)")
plural_po_regex = re.compile(r"(?<=msgid\s)\".*?(?<!\\)\"(?=\s+msgid_plural)")
po_find_regex = re.compile(r'(?<=gettext\.textdomain\(\')[a-z]+-[a-z]*-*[a-z]+(?=\'\))')
normal_trans_regex = re.compile(r"(?<=\(T|\{T|\sT|\[T)\".*?(?<!\\)\"(?=,|\s|\s\.\.|\.\.|\)|\}|\")")
accent_trans_regex = re.compile(r"(?<=\(T|\{T|\sT|\[T)\'.*?(?<!\\)\'(?=,|\s|\s\.\.|\.\.|\)|\}|\")")
plural_trans_regex = re.compile(r"(?<=\(N\(|\[N\(|\{N\(|\sN\()\".*?\\*?\",\W*\".*?(?<!\\)\"(?=,|\s|\s\.\.|\.\.|\))")
first_plur_regex = re.compile(r'\".*?(?<!\\)\"(?=,|\s+,)')
second_plur_regex = re.compile(r'(?<=\s|,)\".*?(?<!\\)\"')

msgid_po_regex = re.compile(r"(?<=msgid\s)\".*?(?<!\\)\"")

translate_table={}
plur_table={}
plurs_table={}

for root, dirs, files in os.walk(lang_path):
  for dir in dirs:
    po_table[dir]=[]
    po_string_table[dir] = {}
    plur_po_string_table[dir] = {}
    for root, dirs, files in os.walk(lang_path+"/"+dir):
      for file in files:
        translate_table[file.replace(".po","")] = ()
        plur_table[file.replace(".po","")] = ()
        plurs_table[file.replace(".po","")] = {}
        po_table[dir].append(os.path.join(root, file))
        po_file = open(os.path.join(root, file), 'r',encoding='UTF8')
        string_file = po_file.read()
        po_string_table[dir][file.replace(".po","")] = tuple([ s[1:-1] for s in normal_po_regex.findall(string_file)])
        plur_po_string_table[dir][file.replace(".po","")] = tuple(plural_po_regex.findall(string_file))
        po_file.close()

for root, dirs, files in os.walk("decompressed"):
    for file in files:
        if file.endswith(".lp") or file.endswith(".lua"):
          search_file = open(os.path.join(root, file), 'r',encoding='UTF8')
          string_file = search_file.read()
          po_file = po_find_regex.findall(string_file)
          if len(po_file) == 1:
            translate_table[po_file[0]] += tuple([ s[1:-1] for s in normal_trans_regex.findall(string_file)])
            translate_table[po_file[0]] += tuple([ s[1:-1].replace('"','\\\"') for s in accent_trans_regex.findall(string_file)])
            plural_string = plural_trans_regex.findall(string_file)
            for string in plural_string:
              plur_table[po_file[0]] += tuple(first_plur_regex.findall(string))
              plurs_table[po_file[0]][first_plur_regex.findall(string)[0]] = second_plur_regex.findall(string)[0]
          search_file.close()
          
for lang in po_string_table:
  for file in po_string_table[lang]:
    if file in translate_table and file in po_string_table[lang]:
      diff_table = set(translate_table[file]) - set(po_string_table[lang][file])
      po_file = open(lang_path+"/"+lang+"/"+file+".po", 'a',encoding='UTF8')
      for string in diff_table:
        print("Found missing "+string+" in "+file+" for "+lang)
        po_file.write("\nmsgid "+"\""+string+"\""+"\nmsgstr \"\"\n")
      po_file.close()
      diff_table = set(plur_table[file]) - set(plur_po_string_table[lang][file])
      po_file = open(lang_path+"/"+lang+"/"+file+".po", 'a',encoding='UTF8')
      for string in diff_table:
        print("Found missing "+string+" in "+file+" for "+lang)
        po_file.write("\nmsgid "+string+"\nmsgid_plural "+plurs_table[file][string]+"\nmsgstr[0] \"\"\nmsgstr[1] \"\"\n")
      po_file.close()

if len(sys.argv) == 2:
  if sys.argv[1] == "clean":
  
    skip_line = 0
    
    for lang in po_string_table:
      for file in po_string_table[lang]:
        po = open(lang_path+"/"+lang+"/"+file+".po", 'r',encoding='UTF8')
        po_line = po.readlines()
        po.close
        po = open(lang_path+"/"+lang+"/"+file+".po_cleaned", 'w',encoding='UTF8')
        for line in po_line:
          if skip_line != 0:
            skip_line = skip_line - 1
          elif "msgid" in line and not "msgid \"\"" in line:
            old_String = line
            if "msgid_plural" in po_line[po_line.index(line)+1] and len(msgid_po_regex.findall(line)) > 0 and not msgid_po_regex.findall(line)[0] in plur_table[file]:
              #print("Removing "+msgid_po_regex.findall(line)[0]+" from "+file+" in "+lang)
              skip_line = 4
            elif not "msgid_plural" in po_line[po_line.index(line)+1] and len(msgid_po_regex.findall(line)) > 0 and not msgid_po_regex.findall(line)[0] in translate_table[file]:
              #print("Removing "+msgid_po_regex.findall(line)[0]+" from "+file+" in "+lang)
              skip_line = 2
            else:
              po.write(line)
          else:
            po.write(line)
        po.close()
