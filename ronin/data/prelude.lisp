; Ronin v1.00

(def logo-path "M60,60 L195,60 A45,45 0 0,1 240,105 A45,45 0 0,1 195,150 L60,150 M195,150 A45,45 0 0,1 240,195 L240,240 ")

(clear)
 
(resize 600 600)

(def bg 
    (rect 0 0 600 600))
(fill bg "white")

(stroke 
   (svg 140 140 logo-path) "black" 7)