# Custom Navigation Plugin based on initial code structure from https://github.com/govdelivery/jekyll-nested-menu-generator
# Updated to allow for dynamic navigation via the URL string
# ie from /documents/documentation/iOS/Integration/SDK
# and /documents/documentation/iOS/Analytics/Report
# Generates collapsible navigation using bootstrap 4.1
# documents -
#   documentation -
#     iOS +
#       Integration +
#         SDK
#       Analytics +
#         Report
# Usage {% UrlNavMenu {{page.collection}} %}
#

module Jekyll

  class UrlNavMenu < Liquid::Tag
    # @@logs = File.open('../log.txt', 'w')

    def initialize(tag_name, menu_root, tokens)
      @menu_root = menu_root.strip

      @minlevel = 1
      # Class object specific variables
      @menu_nav_list = :menu_nav_list
      @menu_nav_pages = :menu_nav_pages
      @menu_sorted_list = :menu_sorted_list
      @nav_exclude = {
        @menu_nav_list => true,
        @menu_nav_pages => true,
        @menu_sorted_list => true
      }

      # Output options
      @nav_toggle_class = 'nav_toggle'
      @nav_item_class = 'nav-item'
      @nav_item_link_class = 'nav_link'
      @nav_prefix = 'nav'
      @nav_active_page_class = 'nav_url'
      @nav_active_basic_class = 'nav_reg'
      @nav_title_class = 'nav_title'
      @nav_title_block = 'nav_block'
      @page_weight = 'page_order'

      @page_hidden = 'hidden'
      @page_nav_title = 'nav_title'
      @page_config_only = 'config_only'

      # Nav page column index
      @page_key_index = 0
      @page_pg_index = 1
      @page_title_index = 2
      @page_weight_index = 3
      @page_id_index = 4
      @page_url_index = 5

      @fa_class = 'fas' # Font Awesome Class
      @activeclass = ' active'
      @activeparentclass = ' active_parent'

      @unique_postfix = "_nav_page"

      super
    end


    def render(context)
      # save base url
      @baseurl = context.registers[:site].baseurl

      menu(context)

    end

    private
      def menu(context)
         # use variable as value instead of the variable itself
        params = Liquid::Template.parse(@menu_root).render(context).split('|')
        @minlevel = params[0].to_i
        collection = params[1]

        @currentpage = context.registers[:page]
        Jekyll.logger.debug("Current Page: " + @currentpage.id)

        # print @currentpage.id +  ' '
        # puts @minlevel

        site_data_key = collection + @unique_postfix
        root_string = "/" + collection

        # create an nested hash of arrays for easier and faster usage
        if not context['site']['data'].include?(site_data_key)
          #puts site_data_key
          menu_hash = {}
          menu_items = ''
          context['site']['documents'].find_all{|page| page.url.start_with?(root_string)}.each do |page|
            unless page.data[@page_hidden] == true
              path_parts = page.url.split('/')
              Jekyll.logger.debug("Nav for: " + page.url)

              if path_parts.shift
                path_url = '/'
                if path_url += path_parts.shift  # ignore collection name from menu
                  path_url += '/'

                  cnt = 0
                  max_len = path_parts.length
                  cur_hash = menu_hash
                  # puts path_parts.to_s
                  page_weight =  page.data[@page_weight]  || nil # ascending weight


                  while cnt <= max_len
                    path_part = path_parts.shift
                    if path_part
                      path_key = path_part.downcase

                      path_url += path_part + '/'
                      if path_parts.length > 0
                        if cur_hash[path_key].nil?
                          cur_hash[path_key] = {}
                        end

                        if cur_hash[@menu_nav_list].nil?
                          cur_hash[@menu_nav_list] = {}
                        end
                        # Ensure there's always a navigation path
                        if cur_hash[@menu_nav_list][path_key].nil?
                          page_title = path_part.to_s.gsub("%20", ' ').gsub("+", ' ').gsub('_',' ').gsub("%26",'&').gsub("%2F",'/').gsub("%3A",':').gsub("%3F",'?').gsub("%2C",',').gsub("%2B",'+')

                          cur_hash[@menu_nav_list][path_key] = [path_key, path_part,page_title,nil,path_url,path_url]
                        end
                        cur_hash = cur_hash[path_key]

                      else
                        page_title = page.data[@page_nav_title] || page.data['title']
                        page_title = page_title.to_s
                        # fix %20 spaces and other Jekyll Escape
                        page_title = page_title.gsub("%20", ' ').gsub("+", ' ').gsub('_',' ').gsub("%26",'&').gsub("%2F",'/').gsub("%3A",':').gsub("%3F",'?').gsub("%2C",',').gsub("%2B",'+')
                        # Save list of url paths, and if they have pages associated with them
                        if cur_hash[@menu_nav_list].nil?
                          cur_hash[@menu_nav_list] = {}
                        end
                        nav_page_url = page.url
                        unless page.data['custom_url'].nil?
                          nav_page_url = page.data['custom_url']
                        end
                        page_id = ''
                        unless page.id.nil?
                          page_id = page.id
                        end
                        cur_hash[@menu_nav_list][path_key] = [path_key, path_part,page_title,page_weight,page_id, nav_page_url] #, page.path]

                        if cur_hash[@menu_nav_pages].nil?
                          cur_hash[@menu_nav_pages] = {}
                        end

                        #puts path_part
                        unless page.data[@page_config_only]
                          cur_hash[@menu_nav_pages][path_key] = page # "page"
                        end
                        # end loop
                        cnt = max_len
                      end
                    end
                    cnt += 1
                  end
                end
              end
            end
          end

          #puts menu_html
          context['site']['data'][site_data_key] = menu_hash # build_menu_html(menu_hash,'',0) # Cache menu results
          #build_menu_html(menu_hash,'',0)
          #puts menu_hash.to_s.gsub(/\=\>/,': ').gsub(/\:menu_nav_list/,' "menu_nav_list"').gsub(/\:menu_nav_pages/,' "menu_nav_pages"').gsub(/\:menu_sorted_list/,' "menu_sorted_list"')  .gsub(/ nil/,' ""')
        end
        build_menu_html(context['site']['data'][site_data_key],'',0)
      end

      def build_menu_html(menu_hash,parent_key,level)
        resultstr = ''

        unless menu_hash.nil?
          # Loop through list of pages on the current navigation, sorted by page weight
          unless menu_hash[@menu_nav_list].nil?
            if menu_hash[@menu_sorted_list].nil?
              menu_hash[@menu_sorted_list] = []

              # Generate unique list of all pages within the directory
              menu_hash[@menu_nav_list].each do |k,v|
                menu_hash[@menu_sorted_list].push(v)
              end

              menu_hash[@menu_sorted_list].sort_by!{|e| [ e[@page_weight_index] ? 0 : 1,  e[@page_weight_index] ]}

            end

            items = ''
            results = ''
            navclass = ''
            ariaexpanded = false
            # if less then 2, then always show
            if level  < @minlevel
                navclass = ' show'
            end


            nextlevel = level + 1

            menu_hash[@menu_sorted_list].each do |ma|
              #puts ma.to_s
              # Ignore plugin specific keys
              page_key =   ''
              curclass = ''

              curinfo  = nil
              item = nil
              currentpage = false
              isactive = false
              # # @@logs << "#{ma }Menu Nav: #{menu_hash[@menu_nav_pages]} \n"
              unless menu_hash[@menu_nav_list].nil?
                page_title =  ma[@page_title_index]

                unless ma[@page_key_index].nil?
                    page_key = ma[@page_key_index].to_s.gsub(/[^0-9a-z]/i, '')
                end

                # Check if it has a page assocated with it
                unless menu_hash[@menu_nav_pages].nil?
                  if menu_hash[@menu_nav_pages][ma[@page_key_index]].is_a?( Jekyll::Document)
                    curinfo = menu_hash[@menu_nav_pages][ma[@page_key_index]]
                    # check if current page
                    if @currentpage.id == ma[@page_id_index]
                      currentpage = true
                    end
                  end
                end


                # process child menu, also allow check if last item in branch
                parentkey = page_key
                unless parent_key.empty?
                  parentkey = parent_key + '_' + page_key
                else
                  parent_key = 'top'
                end
                item = build_menu_html(menu_hash[ma[@page_key_index]],(parentkey) ,nextlevel)
                ariaexpanded = false
                # only set upto min level

                if level  < (@minlevel - 1)
                  ariaexpanded = true
                end

                #puts "#{show_child.to_s} "
                # check if child is active page, if so don't collapse
                unless ma[@page_url_index].nil?
                  if ( @currentpage.url.start_with? ma[@page_url_index])
                  #  print ' match :'
                    navclass = ' show'
                    ariaexpanded = true
                    curclass  << " #{@activeparentclass} "

                  end
                  if level >= (@minlevel - 1 )
                    if @currentpage.url == ma[@page_url_index]
                      #puts "#{ level } current page check #{@currentpage.id} #{ma[@page_id_index]} "

                      ariaexpanded = false
                    end
                  end
                end



                # build menu based on if item has a page or not. if it has a not page, just show title, else add link
                unless curinfo.nil?
                  # check if last item, if so just display list
                  if currentpage
                    curclass << " #{@activeclass } "
                    isactive = true
                  end

                  cur_url = @baseurl + curinfo.url
                  if curinfo['redirect_to']
                    cur_url = curinfo['redirect_to']
                  end
                  items << "<div class='#{@nav_item_class}  #{curclass}' id='parent_#{@nav_prefix}_#{parentkey}' data-parent='parent_#{@nav_prefix}_#{parent_key}'>"
                  # If last item, doesn't need to be collapsible
                  unless item.empty?
                    items << "<div class='#{ @nav_active_page_class }'  data-parent='parent_#{@nav_prefix}_#{parent_key}'><a href='##{@nav_prefix}_#{parentkey}' data-toggle='collapse' data-target='##{@nav_prefix}_#{parentkey}' class='#{@nav_toggle_class} '  aria-expanded='#{ariaexpanded}' data-parent='parent_#{@nav_prefix}_#{parent_key}'><i class='#{@fa_class}'></i><div class='#{ @nav_title_block}'> "
                  else
                    items << "<div class='#{ @nav_active_basic_class }'  data-parent='parent_#{@nav_prefix}_#{parent_key}'><div class='#{ @nav_title_block}'> "
                  end
                  if isactive
                    items << "<div class='#{@nav_title_class}'  data-parent='parent_#{@nav_prefix}_#{parent_key}'>#{page_title} </div>"
                  else
                    items << "<a href='#{ cur_url }' class='#{@nav_item_link_class}' data-parent='parent_#{@nav_prefix}_#{parent_key}'> <div class='#{@nav_title_class}'>#{page_title}</div></a>"
                  end
                  items << "</div></div>\n</div>\n"

                # Last item on the  so just display it as a list
                else
                  items << "<div class='#{@nav_item_class}  #{curclass}' id='parent_#{@nav_prefix}_#{parentkey}' data-parent='parent_#{@nav_prefix}_#{parent_key}'> "

                  # Last item, doesn't need to be collapsible
                  if item.empty?
                    items << " <div class='#{ @nav_title_block}'  data-parent='parent_#{@nav_prefix}_#{parent_key}'><div class='#{ @nav_active_basic_class } #{@nav_title_class}'>"
                    items << "#{page_title}"
                  else
                    items << "<div class='#{ @nav_active_page_class }'  data-parent='parent_#{@nav_prefix}_#{parent_key}'><a href='##{@nav_prefix}_#{parentkey}' data-toggle='collapse' data-target='##{@nav_prefix}_#{parentkey}' class='#{@nav_toggle_class} ' aria-expanded='#{ariaexpanded}' data-parent='parent_#{@nav_prefix}_#{parent_key}'><i class='#{@fa_class}'></i><div class='#{ @nav_title_block}'><div class='#{@nav_title_class}'>#{page_title}</div></a>"
                  end
                  items << "</div></div></div>\n"
                end

                # Append new items to previous list
                unless item.empty?
                  #  puts item
                  items << item
                end

              end

            end


            # Container html if there's items
            unless items.empty?
              results = "<div class='nav flex-column flex-nowrap "
              unless ariaexpanded
                results << ' collapse '
              end
              results << " #{navclass} ' id='#{@nav_prefix}_#{parent_key}'  >\n"
              results << items
              results << "</div>"
            end
            resultstr << results
          end
        end
        resultstr
      end

  end
end

Liquid::Template.register_tag('UrlNavMenu', Jekyll::UrlNavMenu)
