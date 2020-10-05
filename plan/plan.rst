============================
 Honors thesis project plan
============================

:Author: Curtis Millar
:Date: |date|

.. |date| date:: %B %-d, %Y

Changes to seL4
===============

 * seL4 needs some fairly dramatic changes to make it appropriate for
   real-time system use
 * Each of these changes should be addressed an motivated separately as
   much as possible
 * These will all need to be done on experimental branches of the master
   kernel

Analysis
========

 * Use real-time logging in kernel
 * Need to revive kernel log buffer to demonstrate real-time behavior
 * Need a component that can output the log in bulk over network or
   serial.
 * 64-bit word oriented log?
    * Some log operations may use multiple words
 * Circular buffer log
 * Events
    * First word contains a 6-bit event identifier
    * First word contains a 2-bit length (i.e. up to 4 words for an
      event including the start word)
    * First word can make arbitrary use of the remaining word-8 bits.
    * All kernel operations fall between two 'kernel enter' events
    * A kernel exit is implicit

.. code:: c

    #define FIELD(_index, _offset, _length, _shift) \
        ((struct { \
            seL4_UInt64 index; \
            seL4_UInt64 offset; \
            seL4_UInt64 length; \
            seL4_Bool shift; \
        }){_index, _offset, _length, _shift})

    #define BF_BLOCK_MASK(f) \
        (((f.length) >= 64ull) ? ~0ull : (1ull << (f.length)) - 1ull)
    #define BF_MASK(f) \
        (BF_BLOCK_MASK(f) << (f.offset))
    #define BF_SHIFT(f) \
        ((f.shift) ? (f.offset) : 0ull)
    #define BITFIELD_GET(f, buffer) \
        (((buffer)[f.index] & BF_MASK(f)) >> BF_SHIFT(f))
    #define BITFIELD_SET(f, buffer, field) \
        ((buffer)[f.index] = ((buffer)[f.index] & (~BF_MASK(f)) | ((field << BF_SHIFT(f)) & BF_MASK(f))))

    #define EVENT_ID   FIELD(.index = 0, .offset = 0, .length = 6, .shift = true)
    #define EVENT_SIZE FIELD(.index = 0, .offset = 6, .length = 2, .shift = true)

.. code:: c

    #define BF_FIELD(_index, _offset, _length, _shift) \
        (_index, _offset, _length, _shift)

    #define  BF_F_INDEX(_index, _offset, _length, _shift) _index
    #define BF_F_OFFSET(_index, _offset, _length, _shift) _offset
    #define BF_F_LENGTH(_index, _offset, _length, _shift) _length
    #define  BF_F_SHIFT(_index, _offset, _length, _shift) _shift

    #define BF_BLOCK_MASK(f) \
        (((BF_F_LENGTH f) >= 64ull) ? ~0ull : (1ull << (BF_F_LENGTH f)) - 1ull)
    #define BF_MASK(f) \
        (BF_BLOCK_MASK(f) << (BF_F_OFFSET f))
    #define BF_SHIFT(f) \
        ((BF_F_SHIFT f) ? (BF_F_OFFSET f) : 0ull)
    #define BITFIELD_GET(f, buffer) \
        (((buffer)[BF_F_INDEX f] & BF_MASK(f)) >> BF_SHIFT(f))
    #define BITFIELD_SET(f, buffer, field) \
        ((buffer)[BF_F_INDEX f] = ((buffer)[BF_F_INDEX f] & (~BF_MASK(f)) | ((field << BF_SHIFT(f)) & BF_MASK(f))))

    #define EVENT_ID   BF_FIELD(0, 0, 6, 1)
    #define EVENT_SIZE BF_FIELD(0, 6, 2, 1)

.. code:: c

    #define FIELD(_index, _offset, _length, _shift) \
        ((struct { \
            seL4_UInt64 index; \
            seL4_UInt64 offset; \
            seL4_UInt64 length; \
            seL4_Word shift; \
        }){_index, _offset, _length, _shift})

    #define BF_BLOCK_MASK(f) \
        (((seL4_UInt64)((f.length) < 64ull) << (f.length)) - 1ull)
    #define BF_MASK(f) \
        (BF_BLOCK_MASK(f) << (f.offset))
    #define BF_SHIFT(f) \
        (((f.shift) != 0) * (f.offset))
    #define BITFIELD_GET(f, buffer) \
        (((buffer)[f.index] & BF_MASK(f)) >> BF_SHIFT(f))
    #define BITFIELD_SET(f, buffer, field) \
        ((buffer)[f.index] = ((buffer)[f.index] & (~BF_MASK(f)) | ((field << BF_SHIFT(f)) & BF_MASK(f))))

    #define EVENT_ID   FIELD(.index = 0, .offset = 0, .length = 6, .shift = 1)
    #define EVENT_SIZE FIELD(.index = 0, .offset = 6, .length = 2, .shift = 1)

 * Log syscall entry
    * Current thread
    * Invocation label
    * Scheduling instant


 * Log all creation events
    * Created object of type :math:`t` at physical address :math:`p` of
      size :math:`s`.
    * All objects identified by physical address
 * Log all IPC operations
    * Thread at invoked IPC object of type t with  with specified syscall
    * Thread blocks on queue
    * Thread unblocks from queue
    * Thread is released
 * Log all scheduling events
    * Thread released
 * Log external interrupts
    * 
 * Log all faults
    * Thread faulted with fault type

 * Event format
    * Node ID
    * Scheduling instant

Sample components
=================

 * Need a root level admissions/management component
    * How is the time for such a server even managed?
    * Responsible for allocation
 * Need a real-time serial server
    * Interactive serial?
    * Line buffered input to an interactive shell?
 * Serial multiplexer
    * Line oriented
    * Interleaves multiple outputs
    * Has a single input
 * Interactive shell server
    * 
 * Basic device drivers
    * Shared resource servers (filesystem?)

