# Copyright (c) 2009 Todd Willey <todd@rubidine.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

module IfChanges
  def self.included kls
    kls.send :extend, ClassMethods
  end

  module ClassMethods
    ##
    # If a record has change the given field since it was loaded, perform
    # the following action when it is saved.
    #
    # options[:callback] = :before_validation
    # Specify a callback to use (before_save / before_validate / etc)
    #
    def if_changes atr, options={}, &blk
      ar_callback = (options.delete(:callback) || :before_validation).to_sym
      include InstanceMethods
      store_change_callback(atr, ar_callback, &blk)
      add_callback_runner(ar_callback)
    end

    private
    def store_change_callback atr, ar_callback, &blk
      cb = read_inheritable_attribute(:if_change_callbacks)
      cb ||= {}
      cb[ar_callback] ||= {}
      cb[ar_callback][atr.to_sym] ||= []
      cb[ar_callback][atr.to_sym] << blk
      write_inheritable_attribute(:if_change_callbacks, cb)
    end

    def add_callback_runner ar_callback
      callback_list = "@#{ar_callback}_callbacks"
      chain = instance_variable_get(callback_list)
      return if chain and chain.detect{|x| x.identifier == 'if_changes'}
      send ar_callback, :identifier => 'if_changes' do |inst|
        inst.send :run_change_callbacks, ar_callback
      end
    end
  end

  module InstanceMethods
    private
    def run_change_callbacks ar_callback
      cb = self.class.read_inheritable_attribute(:if_change_callbacks)
      return true unless cb
      return true unless cb[ar_callback]
      cb[ar_callback].each do |atr, blks|
        if changes[atr.to_s]
          blks.each do |blk|
            instance_eval &blk
          end
        end
      end
      true
    end
  end
end
