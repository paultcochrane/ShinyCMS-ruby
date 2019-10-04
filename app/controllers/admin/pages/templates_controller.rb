# Admin controller for page templates
class Admin::Pages::TemplatesController < AdminController
  def index
    # List all templates
    @templates = PageTemplate.all
  end

  def new
    # Add a new template
  end

  def create
    # Save new template details
    @template = PageTemplate.new( template_params )

    if @template.save
      flash[ :notice ] = 'New template created'
      redirect_to action: 'edit', id: @template.id
    else
      flash.now[ :alert ] = 'Failed to create new template'
      render action: 'new'
    end
  end

  def edit
    # Edit a template
    @template = PageTemplate.find( params[:id] )
  end

  def update
    # Save edited template details
    @template = PageTemplate.find( params[:id] )

    if @template.update!( template_params )
      flash.now[ :notice ] = 'Template details updated'
    else
      flash.now[ :alert  ] = 'Failed to update template details'
    end

    render :edit
  end

  private

  def template_params
    params.require( :page_template ).permit(
      :name, :description, :filename
    )
  end
end
