# F2.7 do PLANO-KANBAN-CRM-2026.md — visoes salvas do board.
#
# Fecha a lacuna K-05: "cada atendente reconstroi o filtro todo dia". Uma visao
# e um filtro com nome, e a decisao que ela carrega e **minha ou da equipe** —
# por isso `user_id` e `is_shared` sao colunas, nao convencao.
#
# `filters` e jsonb porque os 12 criterios da F1.4 mudam com o plano (a F5 vai
# acrescentar campos customizados). Uma coluna por criterio viraria uma
# migration por filtro novo.
class CreateCrmBoardViews < ActiveRecord::Migration[7.2]
  def change
    create_table :crm_board_views do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.jsonb :filters, null: false, default: {}
      t.string :group_by, null: false, default: 'stage'
      t.string :sort
      t.boolean :is_shared, null: false, default: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    # Duas pessoas podem ter, cada uma, a sua "Radar" — sao visoes diferentes.
    # A mesma pessoa nao pode ter duas.
    add_index :crm_board_views, [:account_id, :user_id, :name],
              unique: true, name: 'index_crm_board_views_unique_name_per_user'

    # O menu carrega as visoes da conta ordenadas; o indice serve essa consulta.
    add_index :crm_board_views, [:account_id, :position],
              name: 'index_crm_board_views_on_account_and_position'
  end
end
