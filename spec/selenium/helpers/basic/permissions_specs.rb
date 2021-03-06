#
# Copyright (C) 2012 - present Instructure, Inc.
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

shared_examples_for "permission tests" do
  include_context "in-process server selenium tests"

  before (:each) do
    course_with_admin_logged_in
  end

  def select_permission_option(permission_name, role, index)
    fj("td[data-permission_name='#{permission_name}'].[data-role_id='#{role.id}'] a").click
    # driver.execute_script("$('td[data-permission_name=\"#{permission_name}\"].[data-role_id=\"#{role.id}\"] a').click()")
    wait_for_ajaximations
    ffj("td[data-permission_name='#{permission_name}'].[data-role_id='#{role.id}'] label")[index].click
    # driver.execute_script("$('td[data-permission_name=\"#{permission_name}\"].[data-role_id=\"#{role.id}\"] label')[#{index}].click()")
    wait_for_ajaximations #Every select needs to wait for for the request to finish
  end

  def select_enable(permission_name, role)
    select_permission_option(permission_name, role, 0) # 0 is Enable
  end

  def select_enable_and_lock(permission_name, role)
    select_permission_option(permission_name, role, 1) # 1 is enabled and locked
  end

  def select_disable(permission_name, role)
    select_permission_option(permission_name, role, 2) # 2 is Disabled
  end

  def select_disable_and_lock(permission_name, role)
    select_permission_option(permission_name, role, 3) # 3 is Disabled and locked
  end

  def select_default(permission_name, role)
    select_permission_option(permission_name, role, 4) # 3 is Disabled and locked
  end

  def add_new_account_role(role_name)
    role = account.roles.build({:name => role_name})
    role.base_role_type = "AccountMembership"
    role.save!
    role
  end

  def add_new_course_role(role_name, role_type = "StudentEnrollment")
    role = account.roles.build({:name => role_name})
    role.base_role_type = role_type
    role.save!
    role
  end

  def verify_title_text(permission_name, role_id, expected_text)
    el = f(%Q{td[data-role_id="#{role_id}"][data-permission_name="#{permission_name}"] a})
    expect(el.attribute('title')).to eq expected_text
    expect(f('.screenreader-only', el)).to include_text expected_text
  end

  describe "Adding new roles" do
    before do
      get url
    end

    it "adds a new account role" do
      role_name = "an account role"

      f("#account_role_link").click
      f('#account-roles-tab a.add_role_link').click
      wait_for_ajaximations
      fj('form input:visible').send_keys(role_name)
      fj('form button.btn-primary:visible').click
      wait_for_ajaximations

      expect(f('#account-roles-tab')).to include_text(role_name)
      new_role = Role.last
      expect(new_role.name).to eq role_name
      expect(new_role.account_role?).to be_truthy
    end

    it "adds a new course role" do
      role_name = "a course role"

      f("#course_role_link").click
      f('#course-roles-tab a.add_role_link').click
      fj('form input:visible').send_keys(role_name)
      fj('form button.btn-primary:visible').click
      wait_for_ajaximations

      expect(f('#course-roles-tab')).to include_text(role_name)
      new_role = Role.last
      expect(new_role.name).to eq role_name
      expect(new_role.course_role?).to be_truthy
    end
  end

  describe "Editing roles" do
    it "edits an account role" do
      role = add_new_account_role("name")
      get url
      f("#account_role_link").click
      fj(".roleHeader a.edit_role:visible").click
      fj('form input:visible').clear
      fj('form input:visible').send_keys("newname")
      fj('form button.btn-primary:visible').click
      wait_for_ajaximations

      expect(f('#account-roles-tab')).to include_text("newname")
      role.reload
      expect(role.name).to eq "newname"
    end

    it "edits a course role" do
      role = add_new_course_role("name")
      get url
      f("#course_role_link").click
      fj(".roleHeader a.edit_role:visible").click
      fj('form input:visible').clear
      fj('form input:visible').send_keys("newname")
      fj('form button.btn-primary:visible').click
      wait_for_ajaximations

      expect(f('#course-roles-tab')).to include_text("newname")
      role.reload
      expect(role.name).to eq "newname"
    end
  end

  describe "Removing roles" do
    context "when deleting account roles" do
      let!(:role_name) { "delete this account role" }

      before do
        @role = add_new_account_role(role_name)
        get url
      end

      it "deletes a role" do
        f("#account_role_link").click
        f(".roleHeader a.delete_role").click
        driver.switch_to.alert.accept
        wait_for_ajaximations

        expect(f('#account-roles-tab')).not_to include_text(role_name)
        @role.reload
        expect(@role.inactive?).to be_truthy
      end
    end

    context "when deleting course roles" do
      let!(:role_name) { "delete this course role" }

      before do
        @role = add_new_course_role(role_name)
        get url
      end

      it "deletes a role" do
        f("#course_role_link").click
        f(".roleHeader a.delete_role").click
        driver.switch_to.alert.accept
        wait_for_ajaximations

        expect(f('#course-roles-tab')).not_to include_text(role_name)
        @role.reload
        expect(@role.inactive?).to be_truthy
      end
    end
  end

  describe "Managing roles" do
    context "when managing account roles" do
      let!(:role_name) { "TestAcccountRole" }
      let!(:permission_name) { "read_sis" } # Everyone should have this permission
      let!(:role) { add_new_account_role role_name }

      before do
        get url
        f("#account_role_link").click
      end

      it "enables a permission" do
        select_enable(permission_name, role)

        wait_for_ajax_requests
        verify_title_text(permission_name, role.id, "Enabled")
        role_override = RoleOverride.where(:role_id => role.id).first
        expect(role_override.enabled).to be_truthy
        expect(role_override.locked).to be_falsey
      end

      it "locks and enables a permission" do
        select_enable_and_lock(permission_name, role)

        wait_for_ajax_requests
        verify_title_text(permission_name, role.id, "Enabled and Locked")
        role_override = RoleOverride.where(:role_id => role.id).first
        expect(role_override.enabled).to be_truthy
        expect(role_override.locked).to be_truthy
      end

      it "disables a permission" do
        select_disable(permission_name, role)

        wait_for_ajax_requests
        verify_title_text(permission_name, role.id, "Disabled")
        role_override = RoleOverride.where(:role_id => role.id).first
        expect(role_override.enabled).to be_falsey
        expect(role_override.locked).to be_falsey
      end

      it "locks and disables a permission" do
        select_disable_and_lock(permission_name, role)

        wait_for_ajax_requests
        verify_title_text(permission_name, role.id, "Disabled and Locked")
        role_override = RoleOverride.where(:role_id => role.id).first
        expect(role_override.enabled).to be_falsey
        expect(role_override.locked).to be_truthy
      end

      it "sets a permission to default" do
        select_disable(permission_name, role)

        wait_for_ajax_requests
        role_override = RoleOverride.where(:role_id => role.id).first
        expect(role_override.nil?).to be_falsey

        select_default(permission_name, role)

        wait_for_ajax_requests
        verify_title_text(permission_name, role.id, "Disabled by Default")
        role_override = RoleOverride.where(:role_id => role.id).first
        expect(role_override.nil?).to be_truthy
      end
    end

    context "when managing course roles" do
      let!(:role_name) { "TestCourseRole" }
      let!(:permission_name) { "read_sis" } # Everyone should have this permission
      let!(:role) { add_new_course_role role_name }

      before do
        get url
        f("#course_role_link").click
      end

      it "enables a permission" do
        select_enable(permission_name, role)

        wait_for_ajax_requests
        role_override = RoleOverride.where(:role_id => role.id).first
        expect(role_override.enabled).to be_truthy
        expect(role_override.locked).to be_falsey
      end

      it "locks and enables a permission" do
        select_enable_and_lock(permission_name, role)

        wait_for_ajax_requests
        role_override = RoleOverride.where(:role_id => role.id).first
        expect(role_override.enabled).to be_truthy
        expect(role_override.locked).to be_truthy
      end

      it "disables a permission" do
        select_disable(permission_name, role)

        wait_for_ajax_requests
        role_override = RoleOverride.where(:role_id => role.id).first
        expect(role_override.enabled).to be_falsey
        expect(role_override.locked).to be_falsey
      end

      it "locks and disables a permission" do
        select_disable_and_lock(permission_name, role)

        wait_for_ajax_requests
        role_override = RoleOverride.where(:role_id => role.id).first
        expect(role_override.enabled).to be_falsey
        expect(role_override.locked).to be_truthy
      end

      it "sets a permission to default" do
        select_disable(permission_name, role)

        wait_for_ajax_requests
        role_override = RoleOverride.where(:role_id => role.id).first
        expect(role_override.nil?).to be_falsey

        select_default(permission_name, role)

        wait_for_ajax_requests
        role_override = RoleOverride.where(:role_id => role.id).first
        expect(role_override.nil?).to be_truthy
      end

      context "when using the keyboard" do
        it "opens the menu on enter keypress" do
          button = fj("td[data-permission_name='#{permission_name}'].[data-role_id='#{role.id}'] a")
          button.send_keys(:enter)
          expect(f('.btn-group.open')).to be_displayed
        end

        it "returns focus back to the button activated upon close" do
          button = fj("td[data-permission_name='#{permission_name}'].[data-role_id='#{role.id}'] a")
          button.send_keys(:enter)
          expect(f('.btn-group.open')).to be_displayed # it opened
          button.send_keys(:escape)
          expect(f("#content")).not_to contain_css('.btn-group.open') # it closed
          check_element_has_focus(button)
        end
      end
    end
  end
end
