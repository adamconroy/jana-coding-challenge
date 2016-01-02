require 'set'
require 'watir'
require 'watir-webdriver'

### Time functions ###

# On gigantic sites (i.e. google.com) this tool could run forever. Let's set an arbitrary
# two minute run time for this example script.
@MAX_RUN_TIME = 120
@START_TIME = Time.now

def times_up
  return Time.now - @START_TIME > @MAX_RUN_TIME
end

### Domain/URL functions ###

def get_domain(url)
  match = url.scan(Regexp.new(/^(?:https?:\/\/)?(?:[^@\/\n]+@)?(?:www\.)?([^:\/\n]+)/im))

  if match && match.length > 0 && match[0] && match[0].length > 0
    return match[0][0]
  end

  return nil
end

def clean_url(url)
  p = url.split("://").last.split("?")[0]

  while p.length > 0 && p[-1, 1].scan(Regexp.new(/[A-Za-z0-9]/)).length == 0
    p = p.chop
  end

  # www is icky
  p.slice! "www."

  p
end

### Global state ###

# Keep our state in a set to streamline dupes/dupe checking
@EMAILS = Set.new

# set up a Watir-driven browser (should open Firefox)
@BROWSER = Watir::Browser.new

@INITIAL_PAGE = ARGV[0].split("://").last.split("?")[0]

# Save the domain to make sure that we don't accidentally navigate off of the page
@DOMAIN = get_domain(@INITIAL_PAGE)

# Dictionary of pages that we know about and indices of divs that we've
# clicked and have yet to click. When we exhaust a leaf node we'll just backtrack
# and keep on clicking.
@QUEUE = {@INITIAL_PAGE => {div: -1, max_div: -1}}

### Execution getters and mutators ###

def cur_page
  clean_url(@BROWSER.url)
end

def check_and_close_popups
  @BROWSER.windows.each do |w|
    if get_domain(w.url) != @DOMAIN
      w.close
    end
  end
end

def add_page_to_queue(page=nil)
  page = page || cur_page
  page = clean_url(page)

  if !page.include?("mailto") && !@QUEUE.keys.include?(page)
    puts "Adding page: #{page}"
    @QUEUE[page] = {div: -1, max_div: -1}
  end
end

def queue_empty
  @QUEUE.keys.each do |page|
    if @QUEUE[page][:div] == -1 || @QUEUE[page][:div] != @QUEUE[page][:max_div]
      return false
    end
  end

  return true
end

def update_max_divs(l)
  @QUEUE[cur_page][:max_div] = l

  if @QUEUE[cur_page][:div] == -1
    @QUEUE[cur_page][:div] = 0
  end
end

def increment_div_index
  @QUEUE[cur_page][:div] = @QUEUE[cur_page][:div] + 1
end

def div_index(page=nil)
  @QUEUE[page || cur_page][:div]
end

def max_div_index(page=nil)
  @QUEUE[page || cur_page][:max_div]
end

def finished_page(page=nil)
  return div_index(page) != -1 && div_index(page) == max_div_index(page)
end

def next_page_in_queue
  @QUEUE.keys.sort.each do |page|
    if !finished_page(page)
      return page
    end
  end

  return nil
end

def remove_next_page_from_queue
  puts "Removing: #{next_page_in_queue} from queue"

  @QUEUE[next_page_in_queue][:div] = 1
  @QUEUE[next_page_in_queue][:max_div] = 1
end

# custom navigation to catch connection refused errors
def navigate(link)
  navigation_complete = false

  while !navigation_complete
    begin
      @BROWSER.goto link
      navigation_complete = true
    rescue
      # oopsy
      remove_next_page_from_queue
      if next_page_in_queue
        @BROWSER.goto next_page_in_queue
      else
        navigation_complete = true
      end
    end
  end
end

# I am aware of the inherent issues with regex-based email validation and how crazy it can get
# but for the purposes of this exercise this one should suffice.
def scan_for_emails
  email_regex = Regexp.new(/\b([a-zA-Z0-9._%+-]+)@([a-zA-Z0-9.-]+?)(\.[a-zA-Z.]*)\b/)

  matches = @BROWSER.html.scan(email_regex).uniq

  matches.each do |match|
    @EMAILS.add "#{match[0]}@#{match[1]}#{match[2]}"
  end
end



### CORE EXECUTION LOGIC ###



# For expediting this script I'm only going to click on divs and directly nagivate to anchor hrefs
# In a more fully featured verison we'd possibly expand it nearly any DOM element that is
# clickable as well as execute more thoroughly through Javascript code.
def process_queue
  add_page_to_queue

  # are we done with the current page yet?
  while !queue_empty && finished_page
    # check for redirects...thanks tumblr
    while next_page_in_queue
      # find the next page in the queue to go to
      navigate next_page_in_queue

      # it redirects, i.e. on tumblr /login just goes to / ...purge the page
      if cur_page != next_page_in_queue
        remove_next_page_from_queue
        navigate next_page_in_queue
      else
        break
      end
    end
  end

  if queue_empty || finished_page
    return false
  end

  puts "VISITING: #{cur_page}"
  old_page = cur_page

  scan_for_emails

  # Get all the divs that we are going to click on
  begin
    divs = @BROWSER.divs.to_a.select {|x| x.visible?}
  rescue Exception => e
    if e.message.include?("Connection refused") || e.message.include?("Window not found.")
      # Something is funky with this page, remove it and keep going
      remove_next_page_from_queue

      @BROWSER = Watir::Browser.new

      if next_page_in_queue
        navigate next_page_in_queue
      end

      return false
    end

    raise e
  end
  
  # set the max divs on there, it's fine if it's already set
  update_max_divs(divs.length)
  
  # Get all the links and add them to the queue
  links = @BROWSER.links.to_a.select {|x| x.visible?}

  links.each do |link|
    if link.href && link.href.length > 0 && get_domain(link.href) == @DOMAIN
      add_page_to_queue clean_url(link.href)
    end
  end
  
  while div_index < max_div_index
    puts "Clicking div: #{div_index}"

    div = divs[div_index]
    old_html = @BROWSER.html

    increment_div_index

    # Selenium sometimes "loses" divs because the page may have mutated, etc
    # So we're just going to catch exceptions and keep on truckin. In a real
    # scenario we'd want to regenerate the divs based on an execution tree so
    # we could make sure we hit every possiblity.

    begin
      if div.visible?
        div.click

        # always close popups
        check_and_close_popups

        # if the page navigated away, leave
        if cur_page != old_page
          "Adding page: #{cur_page}"
          add_page_to_queue
          return queue_empty
        end

        # if the html was mutated, double check it for emails
        if @BROWSER.html != old_html
          scan_for_emails
        end
      end
    rescue Exception => e
      puts "Error interacting with div: #{div_index} on #{cur_page} continuing exection..."
    end
  end
end

#########################
# EXECUTION STARTS HERE #
#########################

# call process_queue until there's nothing left to visit or we run out of time
begin
  # we're not using our custom navigate function here because if this one refuses connection
  # there is obviously no reason to continue
  @BROWSER.goto @INITIAL_PAGE

  while !queue_empty
    if times_up
      puts "Ran out of time, terminating execution"
      break
    end

    process_queue
  end

  @BROWSER.close
rescue Exception => e  
  puts e.message  
#  puts e.backtrace.inspect 
end

puts "Emails:"

@EMAILS.each do |email|
  puts email
end
