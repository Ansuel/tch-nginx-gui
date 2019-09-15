import os, re, mmap

from datetime import date
import sys

po_table={}
po_string_table={}
plur_po_string_table={}
lang_path="decompressed/gui_file/www/lang"

#Find msgid in po files
normal_po_regex = re.compile(r"(?<=msgid\s)\".*?(?<!\\)\"(?=\s+msgstr)")
plural_po_regex = re.compile(r"(?<=msgid\s)\".*?(?<!\\)\"(?=\s+msgid_plural)")

#Detect language in lp and lua files
po_find_regex = re.compile(r'(?<=gettext\.textdomain\(\')[a-z]+-[a-z]*-*[a-z]+(?=\'\))')

#Detect T"" in source files
normal_trans_regex = re.compile(r"(?<=\(T|\{T|\sT|\[T)\".*?(?<!\\)\"(?=,|\s|\s\.\.|\.\.|\)|\}|\")")
#Detect T'' in source files
accent_trans_regex = re.compile(r"(?<=\(T|\{T|\sT|\[T)\'.*?(?<!\\)\'(?=,|\s|\s\.\.|\.\.|\)|\}|\")")
#Detect T"" plurar strings
plural_trans_regex = re.compile(r"(?<=\(N\(|\[N\(|\{N\(|\sN\()\".*?\\*?\",\W*\".*?(?<!\\)\"(?=,|\s|\s\.\.|\.\.|\))")
first_plur_regex = re.compile(r'(?<=\").*?(?<!\\)(?=\",|\"\s+,)')
second_plur_regex = re.compile(r'(?<=\s\"|,\").*?(?<!\\)(?=\")')

msgid_po_regex = re.compile(r"(?<=msgid\s\").*(?=\")")

translate_table={}
plur_table={}
plurs_table={}

po_files={}

def gen_tbl_from_po():
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
            plur_po_string_table[dir][file.replace(".po","")] = tuple([ s[1:-1] for s in plural_po_regex.findall(string_file)])
            po_file.close()

def check_files(scanOnly):
    for root, dirs, files in os.walk("decompressed"):
        for file in files:
            if file.endswith(".lp") or file.endswith(".lua"):
              search_file = open(os.path.join(root, file), 'r',encoding='UTF8')
              string_file = search_file.read()
              po_file = po_find_regex.findall(string_file)
              if len(po_file) == 1:
                if scanOnly == "ScanOnly":
                  po_files[po_file[0]] = {}
                  continue
                translate_table[po_file[0]] += tuple([ s[1:-1] for s in normal_trans_regex.findall(string_file)])
                translate_table[po_file[0]] += tuple([ s[1:-1].replace('"','\\\"') for s in accent_trans_regex.findall(string_file)])
                plural_string = plural_trans_regex.findall(string_file)
                for string in plural_string:
                  plur_table[po_file[0]] += tuple(first_plur_regex.findall(string))
                  plurs_table[po_file[0]][first_plur_regex.findall(string)[0]] = second_plur_regex.findall(string)[0]
              search_file.close()

def gen_po():          
    for lang in po_string_table:
      for file in po_string_table[lang]:
        if file in translate_table and file in po_string_table[lang]:
        
          #Normal strings msgid
          diff_table = set(translate_table[file]) - set(po_string_table[lang][file])
          po_file = open(lang_path+"/"+lang+"/"+file+".po", 'a',encoding='UTF8')
          for string in diff_table:
            print("Found missing "+string+" in "+file+" for "+lang)
            po_file.write("\nmsgid "+"\""+string+"\""+"\nmsgstr \"\"\n")
          po_file.close()
          
          #Plural strings
          diff_table = set(plur_table[file]) - set(plur_po_string_table[lang][file])
          po_file = open(lang_path+"/"+lang+"/"+file+".po", 'a',encoding='UTF8')
          for string in diff_table:
            print("Found missing "+string+" in "+file+" for "+lang)
            po_file.write("\nmsgid \""+string+"\"\nmsgid_plural \""+plurs_table[file][string]+"\"\nmsgstr[0] \"\"\nmsgstr[1] \"\"\n")
          po_file.close()

if len(sys.argv) >= 2:
  
  if sys.argv[1] == "clean":
    gen_tbl_from_po()
    check_files("Complete")

    for lang in po_string_table:
      for file in po_string_table[lang]:
        skip_line = 2
        skip_section = 0
        po = open(lang_path+"/"+lang+"/"+file+".po", 'r',encoding='UTF8')
        po_line = po.readlines()
        po.close
        po = open(lang_path+"/"+lang+"/"+file+".po", 'w',encoding='UTF8')
        for line in po_line:
          #Skip first 2 lines
          if skip_line != 0:
            skip_line = skip_line-1
            po.write(line)
            continue
          cleared_line = msgid_po_regex.search(line)
          if skip_section != 0:
            #Skip line until white line, this way we actually remove missing translation by not writing them
            if not line.strip():
                skip_section = 0
          elif cleared_line:
            if not cleared_line.group(0) in translate_table[file] and not cleared_line.group(0) in plur_table[file]:
                print("Removing '"+cleared_line.group(0)+"' from "+file+" in "+lang)
                skip_section = 1
            else:
                #Write if present
                po.write(line)
          else:
            #Write everything else
            po.write(line)
        po.close()
  if sys.argv[1] == "template":
    if len(sys.argv) < 3:
        print("Provide name for lang template")
    else:
        if os.path.exists(lang_path+"/"+sys.argv[2]):
            print("directoy allready exist")
            quit()
        os.mkdir(lang_path+"/"+sys.argv[2])
        check_files("ScanOnly")
        
        for file in po_files:
            po = open(lang_path+"/"+sys.argv[2]+"/"+file+".po", 'w',encoding='UTF8')
            po.write('msgid ""\n')
            po.write('msgstr ""\n')
            po.write('"Project-Id-Version: '+file+'\\n"\n')
            po.write('"Report-Msgid-Bugs-To: \\n"\n')
            po.write('"POT-Creation-Date: '+date.today().strftime("%Y-%m-%d %X")+'\\n"\n')
            po.write('"PO-Revision-Date: \\n"\n')
            po.write('"Last-Translator: \\n"\n')
            po.write('"Language-Team: none\\n"\n')
            po.write('"Language: '+sys.argv[2]+'\\n"\n')
            po.write('"MIME-Version: 1.0\\n"\n')
            po.write('"Content-Type: text/plain; charset=UTF-8\\n"\n')
            po.write('"Content-Transfer-Encoding: 8bit\\n"\n')
            po.write('"Language-Name: \\n"\n')
            po.write('"Plural-Forms: nplurals=2; plural=(n != 1);\\n"\n')
            po.write('"X-Generator: \\n"\n')
            po.write('"X-Poedit-SourceCharset: UTF-8\\n"\n')
            po.close()
        
        gen_tbl_from_po()
        check_files("Complete")
        gen_po()
else:
    gen_tbl_from_po()
    check_files("Complete")
    gen_po()