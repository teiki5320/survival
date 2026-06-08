# Fusionne la vue d'ensemble + le tableau des cartes en un seul plan global.
from PIL import Image
schema=Image.open("docs/histoire_schema.png").convert("RGB")
board =Image.open("docs/histoire_complet.png").convert("RGB")
W=board.width
schema2=schema.resize((W,int(schema.height*W/schema.width)), Image.LANCZOS)
H=schema2.height+30+board.height
c=Image.new("RGB",(W,H),(243,233,214))
c.paste(schema2,(0,0)); c.paste(board,(0,schema2.height+30))
c.save("docs/plan_global.png"); print(c.size)
