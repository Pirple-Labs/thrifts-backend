# app/controllers/api/schemas_controller.rb
module Api
  class SchemasController < Api::BaseController
    # Allow unauthenticated access for schema fetching
    skip_before_action :authenticate_user!, only: [:index, :show], raise: false
    
    # GET /api/schemas
    def index
      category = params[:category]
      
      if category.present?
        # Get latest schema for specific category
        schema = Schema.for_category_latest(category)
        if schema
          render json: {
            success: true,
            schema: serialize_schema(schema)
          }
        else
          render json: {
            success: false,
            error: "No schema found for category: #{category}"
          }, status: :not_found
        end
      else
        # Get all available categories
        categories = Schema.all_categories
        render json: {
          success: true,
          categories: categories.map do |cat|
            schema = Schema.for_category_latest(cat)
            {
              category: cat,
              schema: serialize_schema(schema)
            }
          end
        }
      end
    end
    
    # GET /api/schemas/:id
    def show
      schema = Schema.find_by(id: params[:id])
      
      if schema
        render json: {
          success: true,
          schema: serialize_schema(schema)
        }
      else
        render json: {
          success: false,
          error: "Schema not found"
        }, status: :not_found
      end
    end
    
    # POST /api/schemas (Admin only - for creating new schemas)
    def create
      return render json: { error: "Unauthorized" }, status: :forbidden unless current_user&.admin?
      
      schema = Schema.new(schema_params)
      
      if schema.save
        render json: {
          success: true,
          schema: serialize_schema(schema)
        }, status: :created
      else
        render json: {
          success: false,
          errors: schema.errors.full_messages
        }, status: :unprocessable_entity
      end
    end
    
    # PUT /api/schemas/:id (Admin only - for updating schemas)
    def update
      return render json: { error: "Unauthorized" }, status: :forbidden unless current_user&.admin?
      
      schema = Schema.find_by(id: params[:id])
      return render json: { error: "Schema not found" }, status: :not_found unless schema
      
      if schema.update(schema_params)
        render json: {
          success: true,
          schema: serialize_schema(schema)
        }
      else
        render json: {
          success: false,
          errors: schema.errors.full_messages
        }, status: :unprocessable_entity
      end
    end
    
    private
    
    def schema_params
      params.require(:schema).permit(
        :id, :category, :version, :description, :active,
        schema_json: {}
      )
    end
    
    def serialize_schema(schema)
      {
        id: schema.id,
        category: schema.category,
        version: schema.version,
        description: schema.description,
        active: schema.active,
        fields: schema.fields,
        required_fields: schema.required_fields,
        optional_fields: schema.optional_fields,
        created_at: schema.created_at,
        updated_at: schema.updated_at
      }
    end
  end
end
