require_relative "./database_with_cache"
require "rspec/mocks"

describe DatabaseWithCache do
    before(:each) do
      @book1111 = Book.new('1111','title 1','author 1',12.99, 'Programming', 20 )
      @book5555 = Book.new('5555','title 5','author 5',15.68, 'Programming', 22 )
      @memcached_mock = double()
      @database_mock = double()
      @target = DatabaseWithCache.new @database_mock, @memcached_mock
      @search_array = {"books"=>[{"title"=>"title 1","isbn"=>"1111"},{"title"=>"title 5","isbn"=>"5555"}],"value"=>604.76}
      @json1 = @search_array.to_json
    end

    #test isbnSearch
    describe "#isbnSearch" do
      context "Given the book ISBN is valid" do
        context "and it is not in the local cache" do
          context "nor in the remote cache" do
              it "should read it from the d/b and add it to the remots cache" do
                 expect(@memcached_mock).to receive(:get).with('v_1111').and_return nil
                 expect(@memcached_mock).to receive(:set).with('v_1111',1)
                 expect(@memcached_mock).to receive(:set).with('1111_1',@book1111.to_cache)
                 expect(@database_mock).to receive(:isbnSearch).with('1111').
                                and_return(@book1111)
                 result = @target.isbnSearch('1111')
                 expect(result).to be @book1111
              end
          end
          context "but it is in the remote cache" do
              it "should use the remote cache version and add it to local cache" do
                 expect(@database_mock).to_not receive(:isbnSearch)
                 expect(@memcached_mock).to receive(:get).with('v_1111').and_return 1
                 expect(@memcached_mock).to receive(:get).with('1111_1').
                                                    and_return @book1111.to_cache 
                 result = @target.isbnSearch('1111')
                 expect(result).to eq @book1111
                 # Check it's in local cache 
              end
          end 
        end        
        context "it is in the local cache" do
          before(:each) do
            expect(@database_mock).to_not receive(:isbnSearch) 
            expect(@memcached_mock).to receive(:get).with('v_1111').and_return 1
            expect(@memcached_mock).to receive(:get).with('1111_1'). and_return @book1111.to_cache
            result = @target.isbnSearch('1111')
            expect(result).to eq @book1111 
          end
        context "and up to date with the remote cache" do
          it "should use the local cache version" do
            expect(@database_mock).to_not receive(:isbnSearch) 
            expect(@memcached_mock).to receive(:get).with('v_1111').and_return 1 
            expect(@memcached_mock).to_not receive(:get).with('1111_1')
            result = @target.isbnSearch('1111')
            expect(result).to eq @book1111 
          end
        end
        context "and outdate from the remote cache" do
          it "should use the remote cache version and update the version of local cache" do
            expect(@database_mock).to_not receive(:isbnSearch) 
            expect(@memcached_mock).to receive(:get).with('v_1111').and_return 2 
            expect(@memcached_mock).to receive(:get).with('1111_2').and_return @book1111.to_cache
            result = @target.isbnSearch('1111')
            expect(result).to eq @book1111 
          end
        end 
      end
      context"Given the book ISBN is not valid" do
        it "should return nil" do
          expect(@database_mock).to receive(:isbnSearch).with('1234').and_return nil 
          expect(@memcached_mock).to receive(:get).with('v_1234').and_return nil 
          result = @target.isbnSearch('1234')
          expect(result).to be nil
        end 
      end
    end
    #test updateBook
    describe "#updateBook" do
      context "update the book1111" do
        context "there is no book1111 in remote cache version" do
          it "should be updated in database" do
            expect(@database_mock).to receive(:updateBook).with(@book1111) 
            expect(@memcached_mock).to receive(:get).with('v_1111').and_return nil 
            @target.updateBook(@book1111)
          end
        end
        context "The book1111 is in remote cache version" do
          context "it is not in the local cache" do
            it "should be updated in database and remote cache" do
              expect(@database_mock).to receive(:updateBook).with(@book1111) 
              expect(@memcached_mock).to receive(:get).with('v_1111').and_return 1 
              expect(@memcached_mock).to receive(:set).with('v_1111',2) 
              expect(@memcached_mock).to receive(:set).with('1111_2',@book1111.to_cache) 
              @target.updateBook(@book1111)
            end
          end
        end
        context "it is in the local cache" do
          it "should be updated in database and both cache" do
            expect(@database_mock).to_not receive(:isbnSearch) 
            expect(@memcached_mock).to receive(:get).with('v_1111').and_return 1 
            expect(@memcached_mock).to receive(:get).with('1111_1').and_return @book1111.to_cache 
            result = @target.isbnSearch('1111')
            expect(result).to eq @book1111
            @book1111 = Book.new('1111','title updated','author 1','12.99','Programming','20')

            expect(@database_mock).to receive(:updateBook).with(@book1111) 
            expect(@memcached_mock).to receive(:get).with('v_1111').and_return 1 
            expect(@memcached_mock).to receive(:set).with('v_1111',2) 
            expect(@memcached_mock).to receive(:set).with('1111_2',@book1111.to_cache) 
            @target.updateBook(@book1111)
          end
        end
      end
    end
    #test authorSearch"
    describe "#authorSearch" do
      context "Given the book author is valid" do 
        context "the author is in the remote cache" do
          context "it is updated" do
            it "should return the json value" do
              expect(@database_mock).to_not receive(:authorSearch).with("author 1")
              expect(@memcached_mock).to receive(:get).with("bks_author 1").and_return '1111,5555'
              expect(@memcached_mock).to receive(:get).with("v_1111").and_return 1 
              expect(@memcached_mock).to receive(:get).with("v_5555").and_return 5 
              expect(@memcached_mock).to receive(:get).with("author 1_1111_1_5555_5 ").and_return @json1
            
              result= @target.authorSearch('author 1')
              expect(result).to eq @search_array
            end
          end
          context "and it is outdated" do
            it "should be updated and stored in remote cache" do
              expect(@database_mock).to_not receive(:authorSearch).with("author 1")
              expect(@memcached_mock).to receive(:get).with("bks_author 1").and_return '1111,5555'
              expect(@memcached_mock).to receive(:get).with("v_1111").and_return '1' 
              expect(@memcached_mock).to receive(:get).with("v_5555").and_return '5' 
              expect(@memcached_mock).to receive(:get).with("author 1_1111_1_5555_5 ").and_return nil
              expect(@memcached_mock).to receive(:get).with("1111_1").and_return @book1111.to_cache 
              expect(@memcached_mock).to receive(:get).with("5555_5").and_return @book5555.to_cache 
              expect(@memcached_mock).to receive(:set).with("author 1_1111_1_5555_5 ",@json1)
              result = @target.authorSearch('author 1') 
              expect(result).to eq @search_array
            end
          end
        end
      end
    end
  end    
end
  