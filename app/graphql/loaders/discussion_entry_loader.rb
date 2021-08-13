# frozen_string_literal: true

#
# Copyright (C) 2021 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

class Loaders::DiscussionEntryLoader < GraphQL::Batch::Loader
  def initialize(current_user:, search_term: nil, sort_order: :desc, filter: nil, root_entries: false, relative_entry_id: nil, before_relative_entry: true, include_relative_entry: true)
    @current_user = current_user
    @search_term = search_term
    @sort_order = sort_order
    @filter = filter
    @root_entries = root_entries
    @relative_entry_id = relative_entry_id
    @before_entry = before_relative_entry
    @include_entry = include_relative_entry
  end

  def perform(objects)
    objects.each do |object|
      scope = scope_for(object)
      scope = scope.reorder("created_at #{@sort_order}")
      scope = scope.where(parent_id: nil) if @root_entries
      if @search_term.present?
        # search results cannot look at the messages from deleted
        # discussion_entries, so they need to be excluded.
        scope = scope.active.joins(:user).where(UserSearch.like_condition('message'), pattern: UserSearch.like_string_for(@search_term))
          .or(scope.joins(:user).where(UserSearch.like_condition('users.name'), pattern: UserSearch.like_string_for(@search_term)))
      end

      if @root_entries
        sort_sql = ActiveRecord::Base.sanitize_sql("COALESCE(children.created_at, discussion_entries.created_at) #{@sort_order}")
        scope = scope
          .joins("LEFT OUTER JOIN #{DiscussionEntry.quoted_table_name} AS children
                  ON children.root_entry_id=discussion_entries.id
                  AND children.created_at = (SELECT MAX(children2.created_at)
                                             FROM #{DiscussionEntry.quoted_table_name} AS children2
                                             WHERE children2.root_entry_id=discussion_entries.id)")
          .reorder(Arel.sql(sort_sql))
      end

      if @relative_entry_id
        relative_entry = scope.find(@relative_entry_id)
        condition = @before_entry ? "<" : ">"
        condition += "=" if @include_entry
        scope = scope.where("created_at #{condition}?", relative_entry.created_at)
      end

      scope = scope.joins(:discussion_entry_participants).where(discussion_entry_participants: {user_id: @current_user, workflow_state: 'unread'}) if @filter == 'unread'
      scope = scope.where(workflow_state: 'deleted') if @filter == 'deleted'
      fulfill(object, scope)
    end
  end

  def scope_for(object)
    if object.is_a?(DiscussionTopic)
      object.discussion_entries
    elsif object.is_a?(DiscussionEntry)
      if object.root_entry_id.nil?
        object.root_discussion_replies
      elsif object.legacy?
        object.legacy_subentries
      else
        DiscussionEntry.none
      end
    end
  end

end
