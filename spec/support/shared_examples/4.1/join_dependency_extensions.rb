shared_examples "Join Dependency on ActiveRecord 4.1" do
  it 'joins with symbols' do
    @jd = new_join_dependency(Person, { :articles => :comments }, [])
    @jd.join_constraints([]).should have(2).joins
    @jd.join_constraints([]).each do |join|
      join.class.should eq Squeel::InnerJoin
    end
  end

  it 'joins has_many :through associations' do
    @jd = new_join_dependency(Person, :authored_article_comments, [])
    @jd.join_constraints([]).should have(2).joins
    @jd.join_root.children.first.table_name.should eq 'comments'
  end

  it 'joins with stubs' do
    @jd = new_join_dependency(Person, { Squeel::Nodes::Stub.new(:articles) => Squeel::Nodes::Stub.new(:comments) }, [])
    @jd.join_constraints([]).should have(2).joins
    @jd.join_constraints([]).each do |join|
      join.class.should eq Squeel::InnerJoin
    end
    @jd.join_root.children.first.table_name.should eq 'articles'
    @jd.join_root.children.first.children.first.table_name.should eq 'comments'
  end

  it 'joins with key paths' do
    @jd = new_join_dependency(Person, dsl{ children.children.parent }, [])
    @jd.join_constraints([]).should have(3).joins
    @jd.join_constraints([]).each do |join|
      join.class.should eq Squeel::InnerJoin
    end
    (children_people = @jd.join_root.children.first).aliased_table_name.should eq 'children_people'
    (children_people2 = children_people.children.first).aliased_table_name.should eq 'children_people_2'
    children_people2.children.first.aliased_table_name.should eq 'parents_people'
  end

  it 'joins with key paths as keys' do
    @jd = new_join_dependency(Person, dsl{ { children.parent => parent } }, [])
    @jd.join_constraints([]).should have(3).joins
    @jd.join_constraints([]).each do |join|
      join.class.should eq Squeel::InnerJoin
    end
    (children_people = @jd.join_root.children.first).aliased_table_name.should eq 'children_people'
    (parents_people = children_people.children.first).aliased_table_name.should eq 'parents_people'
    parents_people.children.first.aliased_table_name.should eq 'parents_people_2'
  end

  it 'joins using outer joins' do
    @jd = new_join_dependency(Person, { :articles.outer => :comments.outer }, [])
    @jd.join_constraints([]).should have(2).joins
    @jd.join_constraints([]).each do |join|
      join.class.should eq Squeel::OuterJoin
    end
  end
end
