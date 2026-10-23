import sys
from PIL import Image
d=sys.argv[1]; out=sys.argv[2]; names=sys.argv[3:]
ims=[Image.open(f"{d}/{n}.png").convert("RGB") for n in names]
w,h=ims[0].size
cols=min(len(ims),4); rows=(len(ims)+cols-1)//cols
sh=Image.new("RGB",(w*cols,h*rows))
for i,im in enumerate(ims): sh.paste(im,((i%cols)*w,(i//cols)*h))
sh.save(out)
