Main command line entry point. This is a pretty simple thing that just walks
over a PNG image, whether in greyscale or color and figure an average 0-255
color weight, then converts that to a GCODE S command expected to be normalized
on 0-255 for laser intensity.

    pngparse = require 'pngparse'
    require 'colors'
    doc = """
    Usage:
      laserify [options] PNG

    Options:
      --help                All about laserify.
      --version             For your semver ponderings.
      --pixels_per_mm=PPMM  Resolution scaling [default: 20].
      --feedrate=FEEDRATE   Laser speed, which will change based on materials and laser wattage [default: 3000].

    Notes:
      This assumes your laser is set up metric. You can of course use a different
      scale -- multiply the pixels_per_mm by 25 for example.
    """

    {docopt} = require 'docopt'
    args = docopt(doc, version: require('../package.json').version)


    scale = 1.0 / Number(args['--pixels_per_mm'])
    feedrate = Number(args['--feedrate'])
    compression = 4

Scale a pixel across the color ranges to get a gray intensity, and
then scale it down by `a` component for transparency through to
the base medium we are engraving.

This does a bit of compression by bit shifting.

Laser is cutting a thing -- so there isn't really multiple color!

    scalePixel = (imageData, x, y) ->
      pixel = imageData.getPixel x, y
      r = ((pixel & 0xFF000000) >> 24) & 255
      g = ((pixel & 0x00FF0000) >> 16) & 255
      b = ((pixel & 0x0000FF00) >> 8) & 255
      a = ((pixel & 0x000000FF) >> 0) & 255
      scaled = Math.floor(((r + g + b) / 3) * (a / 255))
      (scaled >> compression) << compression

    pngparse.parseFile args['PNG'], (err, imageData) ->
      if err
        console.error "#{err}".red
      else
        console.error "#{imageData.width} x #{imageData.height} px".green
        console.error "#{imageData.width * scale} x #{imageData.height * scale} mm".green

        console.log "G0 X0 Y0"
        console.log "M3 S0"

Oh -- coordinate systems. This will scan from the lower left and zig-zag to
avoid the need for multiple fast travel passes.

        for y in [1..imageData.height] by 1
          pixelY = imageData.height - y
          console.log "(line Y #{pixelY})"
          console.log "G1 F#{feedrate} Y#{y*scale}"

Here is an attempt at run-length encoding to cut down the size of gcode files
should work for solid color blocks.

          lastPixel = -1
          if y % 2 is 0
            for x in [0..(imageData.width-1)] by 1
              pixelX = x
              pixel = scalePixel imageData, pixelX, pixelY
              if pixel isnt lastPixel
                lastPixel = pixel
                console.log "  S#{lastPixel} X#{x*scale}"
          else
            for x in [(imageData.width-1)..0] by -1
              pixelX = x
              pixel = scalePixel imageData, pixelX, pixelY
              if pixel isnt lastPixel
                lastPixel = pixel
                console.log "  S#{lastPixel} X#{x*scale}"

And always head to the end of the line in the case we didn't trigger the RLE
above, otherwise lines will be cut off as diagonals!

          console.log "  S#{lastPixel} X#{x*scale}"

        console.log "M5"
        console.log "G0 X0 Y0"
        console.log "M2"
