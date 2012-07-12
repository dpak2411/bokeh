# module setup stuff
if this.Continuum
  Continuum = this.Continuum
else
  Continuum = {}
  this.Continuum = Continuum

class DataTableView extends ContinuumView
  initialize : (options) ->
    super(options)
    @render()
    safebind(this, @model, 'change', @render)

  el: 'div'

  className: 'table table-striped table-bordered table-condensed' 

  render : () ->
    table_template = """
		<table class='table table-striped table-bordered table-condensed' id='{{ tableid }}'></table>
    """
    table_template = """
		<table class='table table-striped table-bordered table-condensed' id='tableid_na'></table>
    """

    header_template = """
      <thead id ='header_id_na'></thead>
    """
    header_column = """
      <th><a href="javascript:cdxSortByColumn()" class='link'>{{column_name}}</a></th>
    """
    row_template = """
      <tr></tr>
    """
    datacell_template = """
      <td>{{data}}</td>
    """

    header = $(header_template)
    for colname in @mget('columns')
      html = _.template(header_column, {'column_name' : colname})
      header.append($(html))
    table = $(table_template);
    table.append(header)
    for rowdata in @mget_ref('data_source').get('data')
      row = $(row_template)
      for colname in @mget('columns')
        datacell = $(_.template(datacell_template,
          {'data' : rowdata[colname]}))
        row.append(datacell)
        table.append(row)
    @$el.html(table)
    if @mget('usedialog') and not @$el.is(":visible")
      @add_dialog()

class TableView extends ContinuumView
  delegateEvents: ->
    safebind(this, @model, 'destroy', @remove)
    safebind(this, @model, 'change', @render)

  render : ->
    super()
    @$el.empty()
    @$el.append("<table></table>")
    @$el.find('table').append("<tr></tr>")
    headerrow = $(@$el.find('table').find('tr')[0])
    for column, idx in ['row'].concat(@mget('columns'))
      elem = $("<th class='tableelem tableheader'>#{column}/th>")
      headerrow.append(elem)
    for row, idx in @mget('data')
      row_elem = $("<tr class='tablerow'></tr>")
      rownum = idx + @mget('data_slice')[0]
      for data in [rownum].concat(row)
        elem = $("<td class='tableelem'>#{data}</td>")
        row_elem.append(elem)
      @$el.find('table').append(row_elem)
    @render_pagination()
    if @mget('usedialog') and not @$el.is(":visible")
      @add_dialog()

  render_pagination : ->
    if @mget('offset') > 0
      node = $("<button>first</button>").css({'cursor' : 'pointer'})
      @$el.append(node)
      node.click(=>
        @model.load(0)
        return false
      )
      node = $("<button>previous</button>").css({'cursor' : 'pointer'})
      @$el.append(node)
      node.click(=>
        @model.load(_.max([@mget('offset') - @mget('chunksize'), 0]))
        return false
      )

    maxoffset = @mget('total_rows') - @mget('chunksize')
    if @mget('offset') < maxoffset
      node = $("<button>next</button>").css({'cursor' : 'pointer'})
      @$el.append(node)
      node.click(=>
        @model.load(_.min([
          @mget('offset') + @mget('chunksize'),
          maxoffset]))
        return false
      )
      node = $("<button>last</button>").css({'cursor' : 'pointer'})
      @$el.append(node)
      node.click(=>
        @model.load(maxoffset)
        return false
      )

class CDXPlotContextView extends DeferredParent
  initialize : (options) ->
    @views = {}
    super(options)

  #events :
  #  "click js-plot_holder" : "open_plot_tab"

  delegateEvents: ->
    safebind(this, @model, 'destroy', @remove)
    safebind(this, @model, 'change', @request_render)

  generate_remove_child_callback : (view) ->
    callback = () =>
      newchildren = (x for x in @mget('children') when x.id != view.model.id)
      @mset('children', newchildren)
      return null
    return callback


  open_plot_tab: (e) ->
    window.e = e
    console.log(' open plot tab ')
    
  make_click_handler: (model, plot_num) ->
    ->
      s_pc = model
      s_pc.set('render_loop', true)
      plotcontextview = new s_pc.default_view(
        model: s_pc, render_loop:true,
        el: $CDX.main_tab_set.add_tab_el(
          tab_name:"plot#{plot_num}",  view: {}, route:"plot#{plot_num}"))
      $CDX.main_tab_set.activate("plot#{plot_num}")

  build_children : () ->
    @mainlist = $("<ul></ul>")
    @$el.append(@mainlist)
    view_specific_options = []
    for spec, plot_num in @mget('children')
      model = @model.resolve_ref(spec)
      model.set({'usedialog' : false})
      plotelem = $("<li id='li#{plot_num}'></li>")
      plotelem.click(@make_click_handler(model, plot_num))
      #@mainlist.append(plotelem)
      view_specific_options.push({'el' : plotelem})
      
    created_views = build_views(
      @model, @views, @mget('children'), {}, view_specific_options)
    window.pc_created_views = created_views
    window.pc_views = @views
    for view in created_views
      safebind(this, view, 'remove', @generate_remove_child_callback(view))
    return null

  render_deferred_components : (force) ->
    super(force)
    @mainlist.html('')
    for view, view_num in _.values(@views)
      view.render_deferred_components(true)
      $.when(view.to_png_daturl()).then((data_url) =>
        console.log('to_png_dataurl called?')
        @mainlist.append("""<li class='js-plot_holder' data-plot_num='#{view_num}'><img width='50' height='50' src='#{data_url}'/></li>"""))
        
    view.render_deferred_components(force)
    
  render : () ->
    super()
    @build_children()
    return null
  
class InteractiveContextView extends DeferredParent
  # Interactive context keeps track of a bunch of components that we render
  # into dialogs

  initialize : (options) ->
    @views = {}
    super(options)

  delegateEvents: ->
    safebind(this, @model, 'destroy', @remove)
    safebind(this, @model, 'change', @request_render)

  generate_remove_child_callback : (view) ->
    callback = () =>
      newchildren = (x for x in @mget('children') when x.id != view.model.id)
      @mset('children', newchildren)
      return null
    return callback

  build_children : () ->
    for spec in @mget('children')
      model = @model.resolve_ref(spec)
      model.set({'usedialog' : true})
    created_views = build_views(@model, @views, @mget('children'))
    for view in created_views
      safebind(this, view, 'remove', @generate_remove_child_callback(view))
    return null

  render_deferred_components : (force) ->
    super(force)
    for view in _.values(@views)
      view.render_deferred_components(force)

  render : () ->
    super()
    @build_children()
    return null

