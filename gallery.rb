require 'active_support/all'
require 'parallel'
require 'mini_magick'
require 'pry'
require 'fileutils'

ROOT = File.expand_path( File.join(__FILE__, '..') )

class Gallery
  
  PER_PAGE = 4 * 20
  TRACKING=''
  IMAGE_TYPES='jpg,JPG,png,PNG'
  OUTPUT_DIR='gallery/'
  
  def self.generate
    new.perform
  end
  
  def perform
    if Dir.glob("*.{#{IMAGE_TYPES}}").reject{|f| f =~ /thumbnail/ }.blank?
      puts "no images found in #{ROOT} matching #{IMAGE_TYPES}"
    else
      reset
      generate_images
      ticker = 0
      images_to_html(images.each_slice(per_page).to_a.first, 0, File.join(OUTPUT_DIR, 'index.html'))
      images.each_slice(per_page) do |some_images|
        images_to_html(some_images, ticker)
        ticker = ticker + 1
      end
      
    end
  end 
  
  def generate_images
    Parallel.map( Dir.glob("*.{#{IMAGE_TYPES}}").reject{|f| f =~ /thumbnail/ }, in_processes: 8 ) do |f| 
      generate_image(f)
      generate_thumbnail(f)
    end
  end
  
  def images_to_html(some_images, ticker=0, name=nil)
    some_images ||= []
    navigation = (images.count / per_page.to_f).ceil.times.collect{|r| %Q{<a class="#{'active' if r == ticker}" href="images-#{r}.html">Page #{r}</a>} }.join("\n")
    html = %Q{
      #{body}
      <div class="navigation">
        #{navigation}
      </div>
      <div class="images">
      #{some_images.join("\n")}
      </div>
      <div class="navigation">
        #{navigation}
      </div>
      #{footer}
    }
    name ||= File.join( OUTPUT_DIR, "images-#{ticker}.html" )
    puts "generate #{name}"
    File.write(name, html)
  end
  
  def images
    ticker = 0
    @images ||= Dir.glob("*.{#{IMAGE_TYPES}}").reject{|f| f =~ /thumbnail/ }.collect do |f| 
      image_fullsize = generate_image(f)
      image_thumbnail = generate_thumbnail(f)
      
      even = (ticker % 2 == 0) ? 'image-even' : 'image-odd'
      third = (ticker % 3 == 0) ? 'image-third' : ''
      fourth = (ticker % 4 == 0) ? 'image-fourth' : ''
      src = %Q{
        <div class="image #{even} #{fourth} #{third} image-#{ticker}">
          <div class="inner-image">
            <a href="#{image_fullsize}" class="fancybox" rel="group" target="_blank"><img src="#{image_thumbnail}" alt="" /></a>
          </div>
        </div>
      }
      ticker = ticker + 1
      src
    end
  end
  
  def body
    %Q{
        <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
        <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
        <head>
        <meta http-equiv="Content-Type" content="text/html;charset=UTF-8" />
        <meta name="robots" content="noindex">
        <meta name="googlebot" content="noindex">
        
        <script type="text/javascript" src="js/jquery-1.10.1.min.js"></script>
        <script type="text/javascript" src="js/jquery.fancybox.js?v=2.1.5"></script>
        <link rel="stylesheet" type="text/css" href="css/jquery.fancybox.css?v=2.1.5" media="screen" />

        <script type="text/javascript">
          $(document).ready(function() {
             $('.fancybox').fancybox();
          });
        </script>
        
        #{tracking_js}
        
        <title>#{title}</title>
        <link rel="stylesheet" href="css/styles.css" />
        </head>
        <body>
        <h1>#{title}</h1>
      }
  end
  
  def footer
    %Q{
      </body>
      </html>
    }
  end
  
  def per_page
    PER_PAGE
  end
  
  def tracking_js
    return if TRACKING == ''
    %Q{
      <script>
        (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
        (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
        m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
        })(window,document,'script','//www.google-analytics.com/analytics.js','ga');

        ga('create', '#{TRACKING}', 'auto');
        ga('send', 'pageview');

      </script>
    }
  end
  
  def generate_image(image_path)
    
    image_output = File.join(OUTPUT_DIR, 'images', image_path)
    
    unless File.exists?(image_output)
      puts "generate_image 1200x800 #{image_output}"
      image = MiniMagick::Image.open(image_path)
      image.auto_orient
      width,height = image['width'],image['height']
      if width > height
        image.resize "1200x800"
      else
        image.resize "800x1200"
      end
      image.write image_output
    end
    image_output.gsub(OUTPUT_DIR, '')
  end
  
  def generate_thumbnail(f)
    image_basename = f.split(".")
    image_ext = image_basename.pop
    image_basename = image_basename.join('.')
    image_thumbnail = File.join(OUTPUT_DIR, 'images', "#{image_basename}-thumbnail.#{image_ext}")
    
    unless File.exists?(image_thumbnail)
      puts "generate_thumbnail 400x260 #{image_thumbnail}"
      image = MiniMagick::Image.open(f)
      image.auto_orient
      width,height = image['width'],image['height']
      if width > height
        image.resize "600x400"
      else
        image.resize "400x600"
      end
      image.write image_thumbnail
    end
    image_thumbnail.gsub(OUTPUT_DIR, '')
  end
  
  def title
    File.basename(File.expand_path('.')).titleize
  end
  
  def reset
    Dir.glob(File.join(OUTPUT_DIR, '*.html')){|f| FileUtils.rm(f) }
    FileUtils.mkdir(OUTPUT_DIR) unless File.exists?(OUTPUT_DIR)
    FileUtils.mkdir(File.join(OUTPUT_DIR,'images')) unless File.exists?(File.join(OUTPUT_DIR,'images'))
    copy('css', 'js')
  end
  
  def copy(*folders)
    folders.each do |folder|
      output_dir = File.join( OUTPUT_DIR, folder )
      puts "copy #{File.join( ROOT, folder )} #{output_dir}"
      FileUtils.rm_rf( output_dir )
      FileUtils.cp_r( File.join( ROOT, folder ), output_dir )
    end
  end
  
end

Gallery.generate