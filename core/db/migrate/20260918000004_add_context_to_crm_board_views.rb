class AddContextToCrmBoardViews < ActiveRecord::Migration[7.1]
  def change
    # 6.3: a mesma tabela passa a guardar visões do board (context 'board') e
    # filtros salvos de relatórios (context 'report'). Coluna em vez de
    # convenção no nome porque muda o que a validação de group_by exige.
    add_column :crm_board_views, :context, :string, default: 'board', null: false
    add_index :crm_board_views, %i[account_id context]

    # A unicidade de nome por usuário passa a valer dentro de cada contexto —
    # "Visão da semana" pode existir no board e nos relatórios sem colidir.
    remove_index :crm_board_views,
                 name: 'index_crm_board_views_unique_name_per_user',
                 column: %i[account_id user_id name]
    add_index :crm_board_views,
              %i[account_id user_id context name],
              unique: true,
              name: 'index_crm_board_views_unique_name_per_user'
  end
end
