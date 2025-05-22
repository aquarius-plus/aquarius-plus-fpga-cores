defint a-z

dim a$(9)
' erase a

for i = 0 to 9
    a$(i) = chr$(65+i)
next

for i = 0 to 9
    print i, a$(i)
next
