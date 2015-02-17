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
      --pixels_per_mm=PPMM  Resolution scaling [default: 100].
      --feedrate=FEEDRATE   Laser speed, which will change based on materials and laser wattage [default: 1000].
    """

    {docopt} = require 'docopt'
    args = docopt(doc, version: require('../package.json').version)


    scale = 1.0 / Number(args['--pixels_per_mm'])
    feedrate = Number(args['--feedrate'])

Scale a pixel across the color ranges to get a gray intensity, and
then scale it down by `a` component for transparency through to
the base medium we are engraving.

Laser is cutting a thing -- so there isn't really multiple color!

    scalePixel = (imageData, x, y) ->
      pixel = imageData.getPixel x, y
      r = ((pixel & 0xFF000000) >> 24) & 255
      g = ((pixel & 0x00FF0000) >> 16) & 255
      b = ((pixel & 0x0000FF00) >> 8) & 255
      a = ((pixel & 0x000000FF) >> 0) & 255
      Math.floor(((r + g + b) / 3) * (a / 255))

    pngparse.parseFile args['PNG'], (err, imageData) ->
      if err
        console.error "#{err}".red
      else
        console.error "#{imageData.width} x #{imageData.height} px".green
        console.error "#{imageData.width * scale} x #{imageData.height * scale} mm".green

Oh -- coordinate systems. This will scan from the lower left and zig-zag to
avoid the need for multiple fast travel passes.

        for y in [(imageData.height-1)..0] by -1
          console.log "G1 F#{feedrate} Y#{y*scale}"
          if y % 2 is 0
            for x in [0..(imageData.width-1)] by 1
              console.log "  S#{scalePixel(imageData, x, y)} X#{x}"
          else
            for x in [(imageData.width-1)..0] by -1
              console.log "  S#{scalePixel(imageData, x, y)} X#{x}"
