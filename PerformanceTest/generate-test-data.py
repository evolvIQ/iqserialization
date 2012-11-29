import json,xmlrpclib
import random
import sys

def random_object(maxdepth=1):
    choices = [random_double, random_int, random_bool, random_string, lambda:None]
    if maxdepth > 0:
        for i in range(1,4):
            choices.append(lambda:random_object(maxdepth-i))
    return random.choice(choices)()
    
def random_int():
    return random.randint(-1000, 1000)
    
def random_bool():
    return bool(random.randint(0,1))

def random_double():
    return random.gauss(0,1e9)
    
def gen_random_string(prefer_ascii):
    s = []
    for _ in range(random.randint(1,100)):
        if not prefer_ascii and random.randint(0,2) == 0 or prefer_ascii and random.randint(0,200) == 0:
            s.append(chr(random.randint(0,255)))
        else:
            s.append(chr(random.randint(ord('a'),ord('z'))))
    return ''.join(s).decode('latin1')
    
strings = None
string_pool = False
def random_string(prefer_ascii=False):
    if string_pool:
        global strings, astrings
        if strings is None:
            strings = [[gen_random_string(False) for _ in range(200)],
                       [gen_random_string(True) for _ in range(200)]]
        return random.choice(strings[prefer_ascii])
    else:
        return gen_random_string(prefer_ascii)
    
if __name__ == '__main__':
    minlen = 10*1024*1024
    if len(sys.argv) > 1:
        minlen = int(sys.argv[1])
    ct = 0
    
    jsonf = file("test.json","w")
    xmlrpcf = file("test.xmlrpc","w")
    print >>jsonf, '{',
    print >>xmlrpcf, '<params><param><value><struct>',
    while ct < minlen:
        if ct > 0:
            print >>jsonf, ','
        else:
            print >>jsonf
        k,v = (json.dumps(random_string(True)), json.dumps(random_object(10)))
        s = '%s : %s' % (k,v)
        ct += len(s)
        print >>jsonf, s,
        xk = xmlrpclib.dumps(({k:v},)).split('<struct>',1)[1].rsplit('</struct>',1)[0].strip()
        print >>xmlrpcf, xk
    print >>jsonf, '}'
    print >>xmlrpcf, '</struct></value></param></params>',
        