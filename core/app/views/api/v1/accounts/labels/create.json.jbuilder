json.id @label.id
json.title @label.title
json.display_title @label.display_title
json.description @label.description
json.color @label.color
json.show_on_sidebar @label.show_on_sidebar
json.category @label.category if @label.respond_to?(:category)
json.slug @label.slug if @label.respond_to?(:slug)
json.scope @label.scope if @label.respond_to?(:scope)
json.is_system @label.is_system if @label.respond_to?(:is_system)
